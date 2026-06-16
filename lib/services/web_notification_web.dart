import 'dart:html' as html;

void showWebNotification(String title, String body) {
  html.Notification(title, body: body);
}
