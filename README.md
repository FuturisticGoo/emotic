<p align="center">
     
  <img src="https://github.com/FuturisticGoo/emotic/blob/5b07913b99662cabeff3ba7a3fd09bb596a335c5/metadata/en-US/images/featureGraphic.png?raw=true" />
</p>

# Emotic 
A Flutter app for showing a list of emoticons and reaction images which can be copied to clipboard or shared for any use.  
(Just an alternative for those websites which do the same, I just wanted something which is available offline)

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/futuristicgoo.emotic/)

Or download the latest APK from the [Releases Section](https://github.com/FuturisticGoo/emotic/releases/latest).

## Features
* A whole bunch of emoticons for your perusal (I'll try to add more)
* Add or modify emoticons
* Add your images or folder of images
* Add tags and notes to those images
* Search using tags and notes
* Reorder them to your liking
* Import and export the database
* That's pretty much it :D

Visit this [link](https://github.com/FuturisticGoo/emotic/issues/19) to download some export files containing emoticons and images.
## Screenshots
|Emoticons|Emotipics|Search and edit|
|-|-|-|
| ![Emotic page](https://github.com/FuturisticGoo/emotic/blob/5b07913b99662cabeff3ba7a3fd09bb596a335c5/metadata/en-US/images/phoneScreenshots/1_main_page.png?raw=true)| ![Emotipics page](https://github.com/FuturisticGoo/emotic/blob/5b07913b99662cabeff3ba7a3fd09bb596a335c5/metadata/en-US/images/phoneScreenshots/4_tag_editor.png?raw=true)| ![Search emotipics](https://github.com/FuturisticGoo/emotic/blob/5b07913b99662cabeff3ba7a3fd09bb596a335c5/metadata/en-US/images/phoneScreenshots/5_settings.png?raw=true) |

## Building
Since this uses Flutter, you obviously need Flutter installed  
```bash
git clone https://github.com/FuturisticGoo/emotic
cd emotic
flutter pub get
flutter build apk --release
```
Use `--flavor=<flavor>` along with the build command, where flavor is either `fdroid` (unsigned) or `independent` (signed, you have to use your own key properties file)   
This app should also work on most platforms Flutter supports (tested on Android and Linux), so go wild with emoticons on your obscure IRC channel, running on an obscure Linux distro ( ಠ‿<)  

## Contributing
You can add new emoticons and images in the app, then export it from the settings page.  
Then upload it to this [issue](https://github.com/FuturisticGoo/emotic/issues/19) so that others can use them.

## License
The assets used in this app, ie the emoticons, tags, are CC0 licensed.

## What does OwO mean?
UwU

