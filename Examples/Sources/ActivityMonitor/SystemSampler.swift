import Foundation

#if os(macOS)
    import Darwin
#endif

// System calls and ps run away from the UI actor. The mounted task awaits each sample,
// so refreshes never overlap and shutdown joins the work before restoring the terminal.
actor SystemSampler {
    private var previousCPU: CPUTicks?

    func sample() throws -> SystemSnapshot {
        let (cpu, memory) = try systemMetrics()
        let processes = try readProcesses()
        let usage = cpu.usage(since: previousCPU)
        previousCPU = cpu
        return SystemSnapshot(date: .now, cpuPercent: usage, memory: memory, processes: processes)
    }

    private func readProcesses() throws -> [ProcessSample] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // No shell, command arguments, or privileged operations. ps supplies OS-reported
        // process CPU percentages, which may exceed 100% on multicore machines.
        process.arguments = ["-ax", "-o", "pid=,ppid=,uid=,pcpu=,rss=,stat=,comm="]
        process.environment = ["LC_ALL": "C", "PATH": "/usr/bin:/bin"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SamplingError.unavailable("process list (ps)") }
        guard let text = String(data: data, encoding: .utf8) else {
            throw SamplingError.unavailable("process names as UTF-8")
        }
        return ProcessSample.parse(text)
    }

    private func systemMetrics() throws -> (CPUTicks, MemorySample) {
        #if os(macOS)
            let host = mach_host_self()
            // mach_host_self returns a send right owned by this sample.
            defer { mach_port_deallocate(mach_task_self_, host) }
            var cpu = host_cpu_load_info()
            var cpuCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
            let cpuResult = withUnsafeMutablePointer(to: &cpu) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
                    host_statistics(host, HOST_CPU_LOAD_INFO, $0, &cpuCount)
                }
            }
            var memory = vm_statistics64()
            var memoryCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            let memoryResult = withUnsafeMutablePointer(to: &memory) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(memoryCount)) {
                    host_statistics64(host, HOST_VM_INFO64, $0, &memoryCount)
                }
            }
            var pageSize: vm_size_t = 0
            guard cpuResult == KERN_SUCCESS, memoryResult == KERN_SUCCESS,
                host_page_size(host, &pageSize) == KERN_SUCCESS
            else { throw SamplingError.unavailable("host statistics") }
            let ticks = cpu.cpu_ticks
            let usedPages =
                UInt64(memory.active_count) + UInt64(memory.wire_count) + UInt64(memory.compressor_page_count)
            return (
                CPUTicks(busy: UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3), idle: UInt64(ticks.2)),
                MemorySample(
                    usedBytes: usedPages * UInt64(pageSize), totalBytes: ProcessInfo.processInfo.physicalMemory)
            )
        #elseif os(Linux)
            return (
                try CPUTicks.linux(String(contentsOfFile: "/proc/stat", encoding: .utf8)),
                try MemorySample.linux(String(contentsOfFile: "/proc/meminfo", encoding: .utf8))
            )
        #endif
    }
}
