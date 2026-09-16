/// Native platforms store the database in a real file inside the app
/// container, which nothing evicts, so there is nothing to ask for.
Future<bool> requestPersistentStorage() async => true;
