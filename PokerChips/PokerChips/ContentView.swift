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
    
    // Blind flags
    var isSmallBlind: Bool = false
    var isBigBlind:   Bool = false
}

// MARK: - Poker Stages
enum GameStage: String {
    case preflop   = "Pre-Flop"
    case flop      = "Flop"
    case turn      = "Turn"
    case river     = "River"
    case showdown  = "Showdown"
    case showCards = "Show Cards"
}

// MARK: - Main Setup View
struct ContentView: View {
    
    // MARK: - State variables
    @State private var numberOfPlayers = 2
    @State private var chipValue = 10       // in cents
    @State private var smallBlind = 1       // in chips
    @State private var bigBlind = 2         // in chips
    @State private var startingChips = 100  // default starting chips for each player
    @State private var players: [Player] = []
    
    let accentColor = Color.pink
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("Chip In Poker")
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
                    Stepper("Chips",
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
                                                         chipValue: chipValue,
                                                         smallBlind: smallBlind,
                                                         bigBlind: bigBlind)) {
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
        numberOfPlayers = 2
        chipValue = 10
        smallBlind = 1
        bigBlind = 2
        startingChips = 100
        updatePlayers()
    }
}

// MARK: - Game View (Betting Logic)
struct GameView: View {
    // Setup data
    @State var players: [Player]
    let chipValue: Int
    let smallBlind: Int
    let bigBlind: Int
    
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
    
    // Count how many "paid bets" happen in Showdown stage
    @State private var showdownBetCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Poker In Progress")
                .font(.title)
                .padding()
            
            // Info row
            HStack {
                Text("Pot: \(pot) (\(currencyString(for: pot)))")
                    .font(.headline)
                    .fontWeight(.bold)

         
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
                    let nameSuffix = blindSuffix(for: player) // e.g. " (Small Blind)" or " (Big Blind)" or ""
                    HStack {
                        Text("\(player.name)\(nameSuffix)")
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
                    // Highlight row if big blind or small blind
                    .listRowBackground(
                        player.isBigBlind
                            ? Color.yellow.opacity(0.3)    // Big Blind = yellow
                            : player.isSmallBlind
                                ? Color.green.opacity(0.3) // Small Blind = green
                                : Color.clear
                    )
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
                    TextField("Chips", text: $raiseAmountString)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
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
        .onAppear {
            // Collect blinds at game start
            startNewRound()
        }
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
    
    /// Assign blinds, subtract chips, and reset data for a fresh round.
    private func startNewRound() {
        // Clear blinds/folds/bets
        for i in players.indices {
            players[i].isSmallBlind = false
            players[i].isBigBlind   = false
            players[i].currentBet   = 0
            players[i].isFolded     = false
        }
        
        pot = 0
        currentHighestBet = 0
        showdownBetCount = 0
        gameStage = .preflop
        
        guard players.count >= 2 else { return }
        
        // Player[0] -> small blind (green), Player[1] -> big blind (yellow)
        players[0].isSmallBlind = true
        players[1].isBigBlind   = true
        
        // Subtract the blinds and add to pot
        let smallBlindAmount = min(players[0].chips, smallBlind)
        players[0].chips -= smallBlindAmount
        players[0].currentBet = smallBlindAmount
        
        let bigBlindAmount = min(players[1].chips, bigBlind)
        players[1].chips -= bigBlindAmount
        players[1].currentBet = bigBlindAmount
        
        pot += smallBlindAmount + bigBlindAmount
        
        // The highest bet is bigBlindAmount
        currentHighestBet = bigBlindAmount
        
        // Let's keep it so the first action is from Player[0]
        currentPlayerIndex = 0
    }
    
    private func callOrCheckAction() {
        let needed = currentHighestBet - players[currentPlayerIndex].currentBet
        if needed <= 0 {
            // CHECK
            nextPlayer()
        } else {
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
        
        // If we're in showdown, track if this was a bet
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
        
        let newBet  = currentHighestBet + raiseAmount
        let needed  = newBet - players[currentPlayerIndex].currentBet
        let actualBet = min(needed, players[currentPlayerIndex].chips)
        
        players[currentPlayerIndex].chips -= actualBet
        players[currentPlayerIndex].currentBet += actualBet
        pot += actualBet
        
        if players[currentPlayerIndex].currentBet > currentHighestBet {
            currentHighestBet = players[currentPlayerIndex].currentBet
        }
        
        // If we're in showdown, track if this was a bet
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
    
    /// Moves turn to the next non-folded player, then checks for round advancement.
    private func nextPlayer() {
        if allButOneFolded() {
            autoAwardToLastStanding()
            return
        }
        
        var nextIndex = currentPlayerIndex
        repeat {
            nextIndex = (nextIndex + 1) % players.count
        } while players[nextIndex].isFolded
        
        currentPlayerIndex = nextIndex
        
        if allActivePlayersMatched() {
            advanceStage()
        }
    }
    
    /// If only one remains, automatically award pot & start new round.
    private func allButOneFolded() -> Bool {
        players.filter { !$0.isFolded }.count == 1
    }
    
    private func autoAwardToLastStanding() {
        guard let lastPlayerIndex = players.firstIndex(where: { !$0.isFolded }) else { return }
        players[lastPlayerIndex].chips += pot
        startNewRound()
    }
    
    /// Move from preflop → flop → turn → river → showdown, then possibly showCards
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
    
    /// Once in showdown, if 2 bets occur, we go to Show Cards.
    private func checkShowCards() {
        if showdownBetCount >= 2 {
            gameStage = .showCards
        }
    }
    
    /// All active players have the same currentBet
    private func allActivePlayersMatched() -> Bool {
        let active = players.filter { !$0.isFolded }
        let firstBet = active.first?.currentBet ?? 0
        return active.allSatisfy { $0.currentBet == firstBet }
    }
    
    /// Manually pick a winner, then start new round
    private func awardPot() {
        players[selectedWinnerIndex].chips += pot
        startNewRound()
    }
    
    /// Add suffix if player is big/small blind
    private func blindSuffix(for player: Player) -> String {
        if player.isBigBlind {
            return " (Big Blind)"
        } else if player.isSmallBlind {
            return " (Small Blind)"
        } else {
            return ""
        }
    }
    
    /// Convert chipCount to dollars
    private func currencyString(for chipCount: Int) -> String {
        let totalCents = chipCount * chipValue
        let totalDollars = Double(totalCents) / 100.0
        return String(format: "$%.2f", totalDollars)
    }
}
