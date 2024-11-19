class MessageModel {
  final String number;
  final String body;

  const MessageModel({required this.number, required this.body});

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(number: json["from"], body: json["message"]);
  }
}
