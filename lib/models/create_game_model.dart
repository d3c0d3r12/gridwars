class CreateGame {
  final String? player1;
  final String? tryy;
  final int? entryFee;
  final int? round;
  final String matrixSize;

  const CreateGame({
    this.player1,
    this.tryy,
    this.entryFee,
    this.round,
    required this.matrixSize,
  });

  Map<String, dynamic> toMap() {
    int numberOfButtons;
    int buttonState;

    // Determine the number of buttons and buttonState based on matrix size
    switch (matrixSize) {
      case "Three": // 3x3 matrix
        numberOfButtons = 9;
        buttonState = 3;
        break;
      case "Four": // 4x4 matrix
        numberOfButtons = 16;
        buttonState = 4;
        break;
      case "Five": // 5x5 matrix
        numberOfButtons = 25;
        buttonState = 5;
        break;
      default:
        throw Exception("Invalid matrix size: $matrixSize");
    }

    // Initialize the buttons map with state, player, row, and column details
    Map<String, Map<String, String>> buttons = {
      for (int i = 0; i < numberOfButtons; i++)
        i.toString(): {
          "state": "", // Initial state
          "player": "0", // Default player
          "row": (i ~/ buttonState).toString(), // Row number
          "column": (i % buttonState).toString(), // Column number
        }
    };

    return {
      "player1": {
        "id": player1,
        "won": 0,
      },
      "try": tryy,
      "time": DateTime.now().toUtc().toString(),
      "entryFee": entryFee,
      "matrixSize": matrixSize,
      "round": round,
      "buttons": buttons,
      "status": "pending",
      "won": "",
      "tie": 0,
    };
  }
}
