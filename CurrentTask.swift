import SwiftUI

// MARK: - Model

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
}

/// Holds the ordered task list and saves it to UserDefaults on every change.
/// The first task in `tasks` is the "current" one shown in the menu bar.
@MainActor
final class TaskStore: ObservableObject {
    private let key = "tasks"

    @Published var tasks: [TaskItem] = [] {
        didSet { save() }
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: key) ?? defaults.string(forKey: key)?.data(using: .utf8),
           let saved = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = saved
        } else if let old = defaults.string(forKey: "currentTask"), !old.isEmpty {
            // Carry over the single task from the first version of the app.
            tasks = [TaskItem(title: old)]
            save() // didSet doesn't fire inside init
            defaults.removeObject(forKey: "currentTask")
        }
    }

    var current: TaskItem? { tasks.first }

    func add(_ title: String, atTop: Bool) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TaskItem(title: trimmed)
        if atTop { tasks.insert(item, at: 0) } else { tasks.append(item) }
    }

    func remove(_ item: TaskItem) {
        tasks.removeAll { $0.id == item.id }
    }

    func moveToTop(_ item: TaskItem) {
        guard let i = tasks.firstIndex(of: item), i > 0 else { return }
        tasks.insert(tasks.remove(at: i), at: 0)
    }

    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - App

@main
struct CurrentTaskApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra {
            TaskListView(store: store)
        } label: {
            // What shows in the menu bar itself: the top task.
            Text(menuBarTitle)
        }
        .menuBarExtraStyle(.window) // a popover window, so text fields and lists work
    }

    private var menuBarTitle: String {
        guard let title = store.current?.title else { return "No task" }
        let extra = store.tasks.count > 1 ? " (+\(store.tasks.count - 1))" : ""
        let max = 40
        let short = title.count > max ? String(title.prefix(max - 1)) + "…" : title
        return short + extra
    }
}

// MARK: - Popover UI

struct TaskListView: View {
    @ObservedObject var store: TaskStore
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tasks").font(.headline)

            HStack {
                TextField("Add a task…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit { addDraft(atTop: false) }
                Button("Add") { addDraft(atTop: false) }
                    .keyboardShortcut(.defaultAction)
                Button {
                    addDraft(atTop: true)
                } label: {
                    Image(systemName: "arrow.up.to.line")
                }
                .help("Add as current task (top of list)")
            }

            if store.tasks.isEmpty {
                Text("No tasks yet. The top task appears in the menu bar.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                List {
                    ForEach(store.tasks) { item in
                        TaskRow(
                            item: item,
                            isCurrent: item == store.current,
                            onTop: { store.moveToTop(item) },
                            onDone: { store.remove(item) }
                        )
                    }
                    .onMove(perform: store.move)
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(store.tasks.count) * 32 + 8, 260))

                Text("Drag to reorder. The top task is shown in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { inputFocused = true }
    }

    private func addDraft(atTop: Bool) {
        store.add(draft, atTop: atTop)
        draft = ""
    }
}

struct TaskRow: View {
    let item: TaskItem
    let isCurrent: Bool
    let onTop: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCurrent ? "star.fill" : "circle")
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 16)
            Text(item.title)
                .fontWeight(isCurrent ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if !isCurrent {
                Button(action: onTop) { Image(systemName: "arrow.up.to.line") }
                    .buttonStyle(.borderless)
                    .help("Make current")
            }
            Button(action: onDone) { Image(systemName: "checkmark.circle") }
                .buttonStyle(.borderless)
                .help("Done (remove)")
        }
        .padding(.vertical, 2)
    }
}
