enum Flavor {
  dev,
  stg,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Stage One App DEV';
      case Flavor.stg:
        return 'Stage One App STG';
      case Flavor.prod:
        return 'Stage One App PROD';
    }
  }

}
