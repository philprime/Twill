import Foundation

/// Keeps task handles until their actions finish, including after their views disappear.
@MainActor
final class MountedTaskRegistry {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func start(priority: TaskPriority, action: @escaping @MainActor @Sendable () async -> Void) -> Task<Void, Never> {
        let id = UUID()
        let task = Task(priority: priority) { @MainActor in
            defer { self.tasks[id] = nil }
            guard !Task.isCancelled else { return }
            await action()
        }
        tasks[id] = task
        return task
    }

    func cancelAll() {
        for task in tasks.values { task.cancel() }
    }

    func join() async {
        for task in Array(tasks.values) { await task.value }
    }
}
