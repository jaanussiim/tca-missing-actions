import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

@main
struct SwiftUICheckApp: App {
    var body: some Scene {
        WindowGroup {
            ApplicationView(
                store: Store(
                    initialState: Application.State(),
                    reducer: Application()
                        .dependency(\.timeEntriesClient, .client)
                )
            )
        }
    }
}

extension TimeEntriesClient {
    internal static let client = TimeEntriesClient(
        onLoadEntries: {
            _ in
                
            try await DispatchQueue.main.sleep(for: .milliseconds(500))
            
            return [
                Entry(id: Int64.random(in: 0...Int64.max)),
                Entry(id: Int64.random(in: 0...Int64.max)),
                Entry(id: Int64.random(in: 0...Int64.max)),
                Entry(id: Int64.random(in: 0...Int64.max)),
                Entry(id: Int64.random(in: 0...Int64.max)),
                Entry(id: Int64.random(in: 0...Int64.max))
            ]
        }
    )
}


public struct TimeEntriesClient {
    internal let onLoadEntries: ((Date) async throws -> [Entry])
}

extension TimeEntriesClient {
    public static let unimplemented = TimeEntriesClient(
        onLoadEntries: XCTUnimplemented("\(Self.self).onLoadEntries")
    )
}

private enum TimeEntriesClientKey: DependencyKey {
    static var liveValue = TimeEntriesClient.unimplemented
    static let previewValue = TimeEntriesClient.unimplemented
    static let testValue = TimeEntriesClient.unimplemented
}

extension DependencyValues {
    public var timeEntriesClient: TimeEntriesClient {
        get { self[TimeEntriesClientKey.self] }
        set { self[TimeEntriesClientKey.self] = newValue }
    }
}


public struct Application: ReducerProtocol {
    public struct State: Equatable {
        internal var timeEntriesState = TimeEntries.State()
    }
    
    public enum Action {
        case timeEntries(TimeEntries.Action)
    }
    
    public var body: some ReducerProtocol<State, Action> {
        Reduce {
            state, action in
        
            switch action {
            case .timeEntries:
                return .none
            }
        }
        Scope(state: \.timeEntriesState, action: /Action.timeEntries) {
            TimeEntries()
        }
    }
}

public struct Entry: Equatable {
    let id: Int64
}

public struct TimeEntry: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public var id: Int64 {
            entry.id
        }
        
        let entry: Entry
    }
    
    public enum Action {
        case tapped
    }
    
    public var body: some ReducerProtocol<State, Action> {
        Reduce {
            state, action in
            
            switch action {
            case .tapped:
                return .none
            }
        }
    }
}

public struct TimeEntries: ReducerProtocol {
    public struct State: Equatable {
        internal var entries = IdentifiedArrayOf<TimeEntry.State>()
        @BindableState var activeDate = Date.now
        @BindableState var overlayDate = Date.now
        internal var calendarShown = false
    }
    
    public enum Action: BindableAction {
        case loadEntries
        case loaded(TaskResult<[Entry]>)
        case toggleCalendar
        
        
        case binding(BindingAction<TimeEntries.State>)
        case timeEntry(id: TimeEntry.State.ID, action: TimeEntry.Action)
    }
    
    @Dependency(\.timeEntriesClient) var timeEntriesClient
    
    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce {
            state, action in
            
            switch action {
            case .binding(\.$activeDate):
                return Effect(value: .loadEntries)
                
            case .loadEntries:
                return Effect.task {
                    [date = state.activeDate] in
                    
                    await .loaded(
                        TaskResult {
                            try await timeEntriesClient.onLoadEntries(date)
                        }
                    )
                }
                
            case .loaded(.failure):
                return .none
                
            case .loaded(.success(let entries)):
                dump(entries)
                state.entries = IdentifiedArrayOf(uniqueElements: entries.map(TimeEntry.State.init(entry:)))
                return .none
                
            case .toggleCalendar:
                state.calendarShown.toggle()
                return .none
                
            case .binding:
                return .none
                
            case .timeEntry:
                return .none
            }
        }
        .forEach(\.entries, action: /Action.timeEntry(id:action:)) {
            TimeEntry()
        }
        .debug()
    }
}

public struct TimeEntriesView: View {
    internal let store: StoreOf<TimeEntries>
    
    public var body: some View {
        WithViewStore(store) {
            viewStore in
            
            NavigationView {
                ZStack {
                    VStack {
                        DatePicker(
                            "Entries on:",
                            selection: viewStore.binding(\.$activeDate), displayedComponents: .date
                        )
                        .padding(.horizontal)
                        List {
                            ForEachStore(store.scope(state: \.entries, action: TimeEntries.Action.timeEntry(id:action:))) {
                                entryStore in
                                
                                WithViewStore(entryStore) {
                                    entryViewStore in
                                    
                                    Text(String(describing: entryViewStore.id))
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                    
                    if viewStore.calendarShown {
                        Color.white.opacity(1)
                        VStack {
                            DatePicker(
                                "Entries on:",
                                selection: viewStore.binding(\.$overlayDate), displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            Spacer()
                        }
                    }
                    
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: { viewStore.send(.toggleCalendar) }) {
                            Image(systemName: "calendar")
                        }
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                viewStore.send(.loadEntries)
            }

        }
    }
}


public struct ApplicationView: View {
    internal let store: StoreOf<Application>
    
    public var body: some View {
        WithViewStore(store) {
            viewStore in
            
            TabView {
                TimeEntriesView(store: store.scope(state: \.timeEntriesState, action: Application.Action.timeEntries))
                    .tabItem {
                        Label("Time entries", systemImage: "rectangle.stack")
                    }
            }
        }
    }
}

