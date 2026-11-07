# ALU Reporting

A Flutter mobile app for ALU students and staff to report and track campus issues such as broken projectors, water shortages and dirty shared spaces. Students submit reports, and staff move each report from Submitted to In Progress to Resolved.

Demo video: https://youtu.be/abUyqjr8wR8

## Features

* Sign up and sign in with ALU emails (@alustudent.com for students, @alueducation.com for staff)
* Submit a report with a category, title, description, campus location and an optional photo
* Browse, search, filter and sort all campus reports
* Report details with a status timeline and staff notes
* Staff update a report's status one step at a time
* Me too: join an existing report instead of filing a duplicate
* Response time targets per category, with overdue reports flagged
* Profile with a photo, filed reports and joined reports

## Built with

* Flutter
* Cubit (flutter_bloc) for state management
* Firebase Authentication, Cloud Firestore and Cloud Storage

## How to run

1. Install Flutter and make sure `flutter doctor` shows no errors.
2. Clone the repository:
   ```
   git clone https://github.com/Peniel-source/alu_report_app.git
   cd alu_report_app
   ```
3. Get the packages:
   ```
   flutter pub get
   ```
4. Start an Android emulator or connect a phone, then run:
   ```
   flutter run
   ```

The Firebase configuration is already included, so the app connects to Firebase without extra setup.

## Accounts

* Sign up with an @alustudent.com email to use the app as a student.
* Sign up with an @alueducation.com email to use the app as staff.

Other email addresses are not accepted.

## Project structure

```
lib/
  main.dart                 starts Firebase and the app
  app.dart                  theme, and decides login or home
  firebase_options.dart     Firebase configuration
  data/
    models.dart             data classes, categories, campus locations
    repositories.dart       all Firebase code
  logic/
    auth_cubit.dart         login and user state
    incident_cubit.dart     reports, search, filters, status updates
  ui/
    screens/                auth, home, report form, reports list, details, profile
    widgets/widgets.dart    reusable widgets
```

## Author

Peniel Nissi Obeng
