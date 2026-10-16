import Foundation
import Twill

struct ActivityMonitorView: View {
    private let sampler = SystemSampler()
    @State private var snapshot: SystemSnapshot?
    @State private var cpuHistory = MetricHistory()
    @State private var memoryHistory = MetricHistory()
    @State private var selectedID: ProcessSample.ID?
    @State private var query = ""
    @State private var paused = false
    @State private var errorMessage = ""
    @State private var sortOrder = [KeyPathComparator(\ProcessSample.cpuPercent, order: .reverse)]

    private var processes: [ProcessSample] {
        (snapshot?.processes ?? []).filter {
            query.isEmpty || $0.command.localizedCaseInsensitiveContains(query) || String($0.id).contains(query)
        }.sorted(using: sortOrder + [KeyPathComparator(\ProcessSample.id)])
    }

    private var selectedProcess: ProcessSample? {
        snapshot?.processes.first { $0.id == selectedID }
    }

    var body: some View {
        let visibleProcesses = processes
        return VStack(alignment: .leading) {
            HStack {
                Text(" ACTIVITY / TWILL ").foregroundStyle(Color.ansi(.cyan))
                Text(paused ? "PAUSED" : "LIVE · 1s")
                    .foregroundStyle(Color.ansi(paused ? .yellow : .green))
                Text("\(snapshot?.processes.count ?? 0) processes")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 1) {
                MetricPanel(
                    title: "CPU · all cores",
                    detail: snapshot?.cpuPercent.map { String(format: "%.1f%% busy", $0) } ?? "Measuring…",
                    values: cpuHistory.values, color: Color.ansi(.cyan))
                MetricPanel(
                    title: "Memory",
                    detail: snapshot?.memory.label ?? "Measuring…",
                    values: memoryHistory.values, color: Color.ansi(.green))
            }
            HStack(spacing: 2) {
                TextField("Filter command or PID", text: $query)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(paused ? "Resume" : "Pause") { paused.toggle() }
                Button("Clear filter") { query = "" }
            }
            .frame(height: 1)
            GroupBox("Processes · \(visibleProcesses.count) matching") {
                processTable(visibleProcesses)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            GroupBox("Selected process") {
                ScrollView {
                    processDetails
                }
                .frame(height: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(statusLine).foregroundStyle(Color.ansi(errorMessage.isEmpty ? .cyan : .red))
            Text("Tab: pane · ↑/↓: select · ↑ at first row: headers · ←/→ Enter: sort · Ctrl-C: quit")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await monitor() }
    }

    private func processTable(_ processes: [ProcessSample]) -> some View {
        Table(processes, selection: $selectedID, sortOrder: $sortOrder) {
            TableColumn("PID", value: \ProcessSample.id) { process in
                Text(String(process.id))
            }
            TableColumn("CPU %", value: \ProcessSample.cpuPercent) { process in
                Text(String(format: "%.1f", process.cpuPercent))
            }
            TableColumn("RSS", value: \ProcessSample.residentBytes) { process in
                Text(MemorySample.format(process.residentBytes))
            }
            TableColumn("State", value: \ProcessSample.status)
            TableColumn("Command", value: \ProcessSample.command) { process in
                Text(String(process.name.prefix(32)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var processDetails: some View {
        if let process = selectedProcess {
            VStack(alignment: .leading) {
                Text(process.command)
                Text("PID \(process.id) · Parent \(process.parentID) · UID \(process.userID) · State \(process.status)")
                Text(
                    "CPU \(String(format: "%.1f", process.cpuPercent))%"
                        + " · Resident \(MemorySample.format(process.residentBytes))"
                )
            }
        } else {
            Text(selectedID == nil ? "Select a process to inspect it." : "Selected process has exited.")
        }
    }

    private var statusLine: String {
        if !errorMessage.isEmpty { return "\(errorMessage) Retrying… Last successful sample retained." }
        #if os(macOS)
            let memoryDefinition = "Memory: active + wired + compressed"
        #else
            let memoryDefinition = "Memory: total − available"
        #endif
        return "\(memoryDefinition) · CPU %: ps-reported, 100% = one core · Read-only"
    }

    private func monitor() async {
        while !Task.isCancelled {
            if !paused {
                do {
                    let next = try await sampler.sample()
                    try Task.checkCancellation()
                    // A pause requested during sampling must not change the frozen display.
                    if !paused {
                        snapshot = next
                        if let cpu = next.cpuPercent { cpuHistory.append(cpu) }
                        memoryHistory.append(next.memory.percent)
                        errorMessage = ""
                    }
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
    }
}
