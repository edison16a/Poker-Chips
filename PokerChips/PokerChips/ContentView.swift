import SwiftUI

@main
struct PokerChipManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Player Model
struct Player: Identifiable {
    let id = UUID()
    var name: String
    var chips: Int
    var currentBet: Int = 0
    var isFolded: Bool = false
}

// MARK: - Poker Stages
enum GameStage: String {
    case preflop  = "Pre-Flop"
    case flop     = "Flop"
    case turn     = "Turn"
    case river    = "River"
    case showdown = "Showdown"
    case showCards = "Show Cards" // New final stage after 2 bets in showdown
}

// MARK: - Main Setup View
struct ContentView: View {
    
    // MARK: - State variables
    @State private var numberOfPlayers = 2
    @State private var chipValue = 10        // in cents
    @State private var smallBlind = 1       // in chips
    @State private var bigBlind = 2        // in chips
    @State private var startingChips = 100  // default starting chips for each player
    @State private var players: [Player] = []
    
    let accentColor = Color.pink
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("All Too Well: Poker Setup")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                    .padding(.top, 16)
                
                // Number of Players
                VStack {
                    Text("Number of Players: \(numberOfPlayers)")
                    Slider(
                        value: Binding(
                            get: { Double(numberOfPlayers) },
                            set: {
                                numberOfPlayers = Int($0)
                                updatePlayers()
                            }
                        ),
                        in: 2...10,
                        step: 1
                    )
                    .accentColor(accentColor)
                }
                
                // Chip Value (in cents)
                VStack {
                    Text("Chip Value: \(chipValue)¢")
                    Slider(
                        value: Binding(
                            get: { Double(chipValue) },
                            set: { chipValue = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    .accentColor(accentColor)
                }
                
                // Small & Big Blinds
                HStack {
                    VStack {
                        Text("Small Blind")
                        TextField("Small Blind", value: $smallBlind, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack {
                        Text("Big Blind")
                        TextField("Big Blind", value: $bigBlind, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Starting Chips
                VStack {
                    Text("Starting Chips: \(startingChips)")
                    Stepper("Set Starting Chips",
                            value: $startingChips,
                            in: 100...100000,
                            step: 100) { _ in
                        updatePlayers()
                    }
                    .frame(width: 200)
                }
                
                // Player name & chips
                List {
                    Section(header: Text("Players & Their Chips")) {
                        ForEach($players, id: \.id) { $player in
                            HStack {
                                TextField("Name", text: $player.name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 150)
                                
                                Spacer()
                                Text("\(player.chips) chips")
                            }
                        }
                    }
                }
                
                // Buttons
                HStack {
                    // Reset
                    Button(action: resetValues) {
                        Text("Reset")
                            .padding()
                            .foregroundColor(.white)
                            .background(accentColor)
                            .cornerRadius(8)
                    }
                    
                    Spacer().frame(width: 20)
                    
                    // Start Game
                    NavigationLink(destination: GameView(players: players,
                                                         chipValue: chipValue)) {
                        Text("Start Game")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
                
                Text("🎵 \"Look what you made me do\" with those chips! 🎵")
                    .italic()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear {
                updatePlayers()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func updatePlayers() {
        let oldPlayers = players
        var newPlayers: [Player] = []
        
        for i in 0..<numberOfPlayers {
            if i < oldPlayers.count {
                var existing = oldPlayers[i]
                existing.chips = startingChips
                newPlayers.append(existing)
            } else {
                newPlayers.append(Player(name: "Player \(i+1)", chips: startingChips))
            }
        }
        
        self.players = newPlayers
    }
    
    func resetValues() {
        numberOfPlayers = 4
        chipValue = 25
        smallBlind = 50
        bigBlind = 100
        startingChips = 1000
        updatePlayers()
    }
}

// MARK: - Game View (Betting Logic)
struct GameView: View {
    // Setup
    @State var players: [Player]
    let chipValue: Int
    
    // Game state
    @State private var currentPlayerIndex: Int = 0
    @State private var pot: Int = 0
    @State private var currentHighestBet: Int = 0
    
    // For the Raise text field
    @State private var raiseAmountString: String = ""
    
    // For awarding the pot
    @State private var selectedWinnerIndex: Int = 0
    
    // Auto stage progression
    @State private var gameStage: GameStage = .preflop
    
    // We'll count how many "paid bets" happen in Showdown stage
    // Once we reach 2, we go to Show Cards
    @State private var showdownBetCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Poker In Progress")
                .font(.title)
                .padding()
            
            // Info row
            HStack {
                Text("Pot: \(pot)")
                Spacer()
                Text("Highest Bet: \(currentHighestBet)")
            }
            .padding(.horizontal)
            
            // Current Stage
            Text("Stage: \(gameStage.rawValue)")
                .font(.headline)
            
            // Current Player (BOLD)
            Text("Current Player: \(players[currentPlayerIndex].name)")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.top, 5)
            
            // Player List
            List {
                ForEach(players) { player in
                    HStack {
                        Text(player.name)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if player.isFolded {
                            Text("Folded")
                                .foregroundColor(.red)
                        } else {
                            Text("\(player.chips) chips")
                            Text("(\(currencyString(for: player.chips)))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Betting Controls
            VStack(spacing: 10) {
                Button(callOrCheckLabel) {
                    callOrCheckAction()
                }
                .disabled(players[currentPlayerIndex].isFolded)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(players[currentPlayerIndex].isFolded ? 0.3 : 1))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                HStack(spacing: 8) {
                    TextField("Enter raise amount in chips", text: $raiseAmountString)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 250) // Wider text field
                        .padding(.leading, 4)
                    
                    // Raise button label
                    Button(raiseButtonLabel) {
                        raiseAction()
                    }
                    .disabled(players[currentPlayerIndex].isFolded)
                    .padding()
                    .background(Color.orange.opacity(players[currentPlayerIndex].isFolded ? 0.3 : 1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button("Fold") {
                    foldAction()
                }
                .disabled(players[currentPlayerIndex].isFolded)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(players[currentPlayerIndex].isFolded ? 0.3 : 1))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Award Pot
            VStack(spacing: 10) {
                Picker("Round Winner", selection: $selectedWinnerIndex) {
                    ForEach(players.indices, id: \.self) { i in
                        Text(players[i].name).tag(i)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                // Button label: "Award Pot of X ($Y) to Winner"
                Button("Award Pot of \(pot) (\(currencyString(for: pot))) to Winner") {
                    awardPot()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            
            Spacer()
        }
        .navigationBarTitle("Game in Progress", displayMode: .inline)
    }
}

// MARK: - Actions & Helpers
extension GameView {
    
    /// The label for the call/check button
    private var callOrCheckLabel: String {
        let needed = currentHighestBet - players[currentPlayerIndex].currentBet
        if needed <= 0 {
            return "Check"
        } else {
            let dollarValue = currencyString(for: needed)
            return "Call \(needed) (\(dollarValue))"
        }
    }
    
    /// The label for the Raise button
    private var raiseButtonLabel: String {
        if let raiseChips = Int(raiseAmountString), raiseChips > 0 {
            let dollarValue = currencyString(for: raiseChips)
            return "Raise \(raiseChips) (\(dollarValue))"
        } else {
            return "Raise"
        }
    }
    
    /// If needed <= 0, that's a Check. Otherwise, it's a Call action.
    private func callOrCheckAction() {
        let needed = currentHighestBet - players[currentPlayerIndex].currentBet
        if needed <= 0 {
            // CHECK
            nextPlayer()
        } else {
            // CALL
            callAction()
        }
    }
    
    private func callAction() {
        let needed = currentHighestBet - players[currentPlayerIndex].currentBet
        let toCall = min(needed, players[currentPlayerIndex].chips)
        
        // Pay the call
        players[currentPlayerIndex].chips -= toCall
        players[currentPlayerIndex].currentBet += toCall
        pot += toCall
        
        // If we're in showdown, count this as a "bet"
        if gameStage == .showdown && toCall > 0 {
            showdownBetCount += 1
            checkShowCards()
        }
        
        nextPlayer()
    }
    
    private func raiseAction() {
        guard let raiseAmount = Int(raiseAmountString), raiseAmount > 0 else {
            return
        }
        
        let newBet = currentHighestBet + raiseAmount
        let needed = newBet - players[currentPlayerIndex].currentBet
        let actualBet = min(needed, players[currentPlayerIndex].chips)
        
        players[currentPlayerIndex].chips -= actualBet
        players[currentPlayerIndex].currentBet += actualBet
        pot += actualBet
        
        if players[currentPlayerIndex].currentBet > currentHighestBet {
            currentHighestBet = players[currentPlayerIndex].currentBet
        }
        
        // If we're in showdown, count this as a "bet"
        if gameStage == .showdown && actualBet > 0 {
            showdownBetCount += 1
            checkShowCards()
        }
        
        raiseAmountString = ""
        nextPlayer()
    }
    
    private func foldAction() {
        players[currentPlayerIndex].isFolded = true
        nextPlayer()
    }
    
    /// Moves turn to the next non-folded player, then checks if the betting round should advance.
    private func nextPlayer() {
        // If everyone but one is folded, auto-award the pot.
        if allButOneFolded() {
            autoAwardToLastStanding()
            return
        }
        
        // Move to next
        var nextIndex = currentPlayerIndex
        repeat {
            nextIndex = (nextIndex + 1) % players.count
        } while players[nextIndex].isFolded
        
        currentPlayerIndex = nextIndex
        
        // If all active players matched the same bet, move to next stage
        if allActivePlayersMatched() {
            advanceStage()
        }
    }
    
    /// Checks if only one player remains.
    private func allButOneFolded() -> Bool {
        players.filter { !$0.isFolded }.count == 1
    }
    
    /// Awards pot automatically to the last player standing, resets for new round.
    private func autoAwardToLastStanding() {
        guard let lastPlayerIndex = players.firstIndex(where: { !$0.isFolded }) else { return }
        
        players[lastPlayerIndex].chips += pot
        pot = 0
        currentHighestBet = 0
        
        // Reset bets/fold
        for i in players.indices {
            players[i].currentBet = 0
            players[i].isFolded = false
        }
        
        // Back to preflop
        gameStage = .preflop
        showdownBetCount = 0
    }
    
    /// Automatically move from preflop → flop → turn → river → showdown (→ showCards if 2 bets).
    private func advanceStage() {
        switch gameStage {
        case .preflop:   gameStage = .flop
        case .flop:      gameStage = .turn
        case .turn:      gameStage = .river
        case .river:     gameStage = .showdown
        case .showdown:  break
        case .showCards: break
        }
        
        // Everyone's bets go into the pot, so reset current bets
        for i in players.indices {
            players[i].currentBet = 0
        }
        currentHighestBet = 0
        
        // If we've just moved to showdown, reset the bet count
        if gameStage == .showdown {
            showdownBetCount = 0
        }
    }
    
    /// Once in showdown, if we get 2 bets, we move to "Show Cards."
    private func checkShowCards() {
        if showdownBetCount >= 2 {
            gameStage = .showCards
        }
    }
    
    /// Check if all active (non-folded) players have the same currentBet.
    private func allActivePlayersMatched() -> Bool {
        let activePlayers = players.filter { !$0.isFolded }
        let firstBet = activePlayers.first?.currentBet ?? 0
        return activePlayers.allSatisfy { $0.currentBet == firstBet }
    }
    
    /// Lets the user manually pick a winner (e.g. at Showdown or Show Cards).
    private func awardPot() {
        players[selectedWinnerIndex].chips += pot
        pot = 0
        currentHighestBet = 0
        
        for i in players.indices {
            players[i].currentBet = 0
            players[i].isFolded = false
        }
        
        // If we were at showdown or showCards, go back to pre-flop
        gameStage = .preflop
        showdownBetCount = 0
    }
    
    /// Helper: chipCount → "$xx.xx"
    private func currencyString(for chipCount: Int) -> String {
        let totalCents = chipCount * chipValue
        let totalDollars = Double(totalCents) / 100.0
        return String(format: "$%.2f", totalDollars)
    }
}
