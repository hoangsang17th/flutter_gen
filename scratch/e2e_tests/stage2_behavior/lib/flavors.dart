enum Flavor {
  dev,
  qa,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Stage One App DEV';
      case Flavor.qa:
        return 'Stage One App QA';
      case Flavor.prod:
        return 'Stage One App PROD';
    }
  }

  static String get baseUrl {
    switch (appFlavor) {
      case Flavor.dev:
        return 'https://dev-api.example.com';
      case Flavor.qa:
        return 'https://qa-api.example.com';
      case Flavor.prod:
        return 'https://prod-api.example.com';
    }
  }
}
