void main() {
  var re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  print('pattern: ' + re.pattern);
  var emails = ['test@gmail.com', 'test@domain.co', 'test@domain', ' test@gmail.com', 'test@gmail.com '];
  for (var email in emails) {
    print('$email => ${re.hasMatch(email)}');
  }
}
