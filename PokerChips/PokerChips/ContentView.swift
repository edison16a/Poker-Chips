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
    var currentBet: Int = 0  // Tracks how much this player has bet in the current round
    var isFolded: Bool = false
}

// MARK: - Main Setup View
struct ContentView: View {
    
    // MARK: - State variables
    @State private var numberOfPlayers = 4
    @State private var chipValue = 25        // in cents
    @State private var smallBlind = 50       // in chips
    @State private var bigBlind = 100        // in chips
    @State private var startingChips = 1000  // default starting chips for each player
    @State private var players: [Player] = []
    
    // Swiftie-inspired color scheme
    let accentColor = Color.pink
    let backgroundColor = Color.white
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // Title
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
                
                // Player name & chips entry
                List {
                    Section(header: Text("Players & Their Chips")) {
                        // Use binding to edit each player's name directly
                        ForEach($players, id: \.id) { $player in
                            HStack {
                                // Name Field
                                TextField("Name", text: $player.name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 150)
                                
                                Spacer()
                                
                                // Show the player's current chips
                                Text("\(player.chips) chips")
                            }
                        }
                    }
                }
                
                // Buttons
                HStack {
                    // Reset Button
                    Button(action: resetValues) {
                        Text("Reset")
                            .padding()
                            .foregroundColor(.white)
                            .background(accentColor)
                            .cornerRadius(8)
                    }
                    
                    Spacer().frame(width: 20)
                    
                    // Start Game
                    NavigationLink(destination: GameView(players: players)) {
                        Text("Start Game")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
                
                // Subtle reference
                Text("🎵 \"Look what you made me do\" with those chips! 🎵")
                    .italic()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear {
                // Initialize the players array at startup
                updatePlayers()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Updates the players array to match the current number of players and starting chip count
    func updatePlayers() {
        // Keep existing names if possible; if shrinking, we lose the extras
        // If expanding, we add new players
        let oldPlayers = players
        
        // Rebuild an array of the new size
        var newPlayers: [Player] = []
        
        for i in 0..<numberOfPlayers {
            if i < oldPlayers.count {
                // Update old player's chips if needed
                var existing = oldPlayers[i]
                existing.chips = startingChips
                newPlayers.append(existing)
            } else {
                // Create a new player with default name
                newPlayers.append(Player(name: "Player \(i+1)", chips: startingChips))
            }
        }
        
        self.players = newPlayers
    }
    
    /// Resets all values to default
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
    @State var players: [Player]  // We copy the list from the setup
    @State private var currentPlayerIndex: Int = 0
    @State private var pot: Int = 0
    @State private var currentHighestBet: Int = 0
    
    // For the Raise text field
    @State private var raiseAmountString: String = ""
    
    // For awarding the pot
    @State private var selectedWinnerIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Poker In Progress")
                .font(.title)
                .padding()
            
            // Display pot and highest bet info
            HStack {
                Text("Pot: \(pot)")
                Spacer()
                Text("Highest Bet: \(currentHighestBet)")
            }
            .padding(.horizontal)
            
            // Current player information
            Text("Current Player: \(players[currentPlayerIndex].name)")
                .font(.headline)
                .padding(.top, 10)
            
            // Display each player's chips and whether they're folded
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
                        }
                    }
                }
            }
            
            // Betting Controls
            VStack(spacing: 10) {
                // Call Button
                Button("Call") {
                    callAction()
                }
                .disabled(players[currentPlayerIndex].isFolded)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(players[currentPlayerIndex].isFolded ? 0.3 : 1))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // Raise UI
                HStack(spacing: 8) {
                    TextField("Raise Amount", text: $raiseAmountString)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                    
                    Button("Raise") {
                        raiseAction()
                    }
                    .disabled(players[currentPlayerIndex].isFolded)
                    .padding()
                    .background(Color.orange.opacity(players[currentPlayerIndex].isFolded ? 0.3 : 1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Fold Button
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
            
            // Award Pot / Next Round
            VStack(spacing: 10) {
                Picker("Round Winner", selection: $selectedWinnerIndex) {
                    ForEach(players.indices, id: \.self) { i in
                        Text(players[i].name).tag(i)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button("Award Pot to Winner") {
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

// MARK: - Betting Actions
extension GameView {
    
    private func callAction() {
        var player = players[currentPlayerIndex]
        
        // How much this player needs to match the current highest bet
        let needed = currentHighestBet - player.currentBet
        
        // If the player doesn't have enough chips to call, they put in all they have
        let actualCall = min(needed, player.chips)
        
        // Update player's chips, pot, and player's current bet
        player.chips -= actualCall
        pot += actualCall
        player.currentBet += actualCall
        
        players[currentPlayerIndex] = player
        
        // Move to next player
        nextPlayer()
    }
    
    private func raiseAction() {
        guard let raiseAmount = Int(raiseAmountString), raiseAmount > 0 else {
            return // invalid input
        }
        
        var player = players[currentPlayerIndex]
        
        // New bet is the current highest bet plus the raise
        let newBet = currentHighestBet + raiseAmount
        
        // Additional chips needed from player
        let needed = newBet - player.currentBet
        
        // If the player doesn't have enough to raise fully, just do all-in
        let actualBet = min(needed, player.chips)
        
        player.chips -= actualBet
        pot += actualBet
        player.currentBet += actualBet
        
        // Update highest bet
        if player.currentBet > currentHighestBet {
            currentHighestBet = player.currentBet
        }
        
        players[currentPlayerIndex] = player
        raiseAmountString = ""
        
        // Move to next player
        nextPlayer()
    }
    
    private func foldAction() {
        players[currentPlayerIndex].isFolded = true
        nextPlayer()
    }
    
    /// Moves turn to the next player who isn't folded, if possible
    private func nextPlayer() {
        var nextIndex = currentPlayerIndex
        
        repeat {
            nextIndex = (nextIndex + 1) % players.count
        } while players[nextIndex].isFolded && !allButOneFolded()
        
        // If all but one are folded, you might want to handle awarding pot automatically
        // (This example just cycles to the next non-folded player)
        currentPlayerIndex = nextIndex
    }
    
    /// Helper to see if only one player is left
    private func allButOneFolded() -> Bool {
        players.filter { !$0.isFolded }.count <= 1
    }
    
    /// Awards the current pot to the selected winner and resets for the next round
    private func awardPot() {
        // Give pot to the selected winner
        players[selectedWinnerIndex].chips += pot
        
        // Reset pot and bets
        pot = 0
        currentHighestBet = 0
        
        // Reset each player's bet and folding status for next round
        for i in players.indices {
            players[i].currentBet = 0
            players[i].isFolded = false
        }
        
        // Start next round with the same currentPlayerIndex (or shift blinds, etc.)
        // For simplicity, we leave that logic out. You could incorporate blind rotation here.
    }
}
