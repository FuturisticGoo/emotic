# Emotic 
A Flutter app for showing a list of emoticons which can be copied to clipboard for any use.  
(Just an alternative for those websites which do the same, I just wanted something which is available offline)

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/futuristicgoo.emotic/)

Or download the latest APK from the [Releases Section](https://github.com/FuturisticGoo/emotic/releases/latest).

## Features
* A whole bunch of emoticons for your perusal (I'll try to add more)
* Add or modify emoticons
* Search using related tags
* That's pretty much it :D

## Building
Since this uses Flutter, you obviously need Flutter installed  
```bash
git clone https://github.com/FuturisticGoo/emotic
cd emotic
flutter pub get
flutter build apk --release
```
This app should also work on all platforms Flutter supports, so go wild with emoticons on your obscure IRC channel, running on an obscure Linux distro ( ಠ‿<)  

## Contributing
You can fork and add new emoticons and tags in the asset file itself by running  
``` bash
dart run bin/asset_helper.dart
```  
Which should give you a terminal wizard for adding, removing emoticons and tags, and linking the tags with emoticons.  
You could then submit a pull request. I might accept it, or not.

## License
The assets used in this app, ie the emoticons csv, tags, icon, are CC0 licensed.

## What does OwO mean?
UwU

