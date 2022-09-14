import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

@main
struct SwiftUICheckApp: App {
    private let appStore = Store(initialState: Application.State(), reducer: Application())
    private let entriesStore = Store(initialState: TimeEntries.State(), reducer: TimeEntries())
    
    var body: some Scene {
        WindowGroup {
            TabView {
                TimeEntriesView(
                    store: appStore.scope(state: \.timeEntriesState, action: Application.Action.timeEntries)
                )
                .tabItem {
                    Label("Scoped", systemImage: "star.fill")
                }
                TimeEntriesView(
                    store: entriesStore
                )
                .tabItem {
                    Label("Direct", systemImage: "wand.and.stars")
                }
            }
        }
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

public struct TimeEntries: ReducerProtocol {
    public struct State: Equatable {
        @BindableState var activeDate = Date.now
    }
    
    public enum Action: BindableAction {
        case loadEntries
        
        // ######### comment out
        case loaded(TaskResult<[Entry]>)
        // #########
        
        case binding(BindingAction<TimeEntries.State>)
    }
    
    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce {
            state, action in
            
            switch action {
            case .binding(\.$activeDate):
                return Effect(value: .loadEntries)
                
            case .loadEntries:
                return .none

            // ######### comment out
            case .loaded(let result):
                return .none
            // #########
                                
            case .binding:
                return .none
            }
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
                        Spacer()
                        Text(viewStore.activeDate, style: .date)
                    }
                }
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

