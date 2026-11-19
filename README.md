# FtoA

Copy layers with ⌘C in Figma Design, switch to Affinity, and paste with ⌘V. FtoA sits in the Mac menu bar and gives Affinity the SVG from Figma's own **Copy as SVG** command.

## Install on a Mac

FtoA runs on macOS 13 or later on Apple silicon and Intel.

1. [Download FtoA-macOS.zip](https://github.com/teodorik/figmatoaffinity/releases/latest/download/FtoA-macOS.zip).
2. Unzip it, drag **FtoA.app** into **Applications**, and open it. The clipboard icon in the menu bar is FtoA.
3. Click the icon and choose **Enable Automatic Copy…**. Turn on FtoA in **System Settings → Privacy & Security → Accessibility**. If macOS asks whether FtoA can read the clipboard, allow it.

The download is ad hoc signed and Apple hasn't notarized it. If macOS stops the first launch, follow [Apple's steps for opening an app you trust](https://support.apple.com/en-us/102445#if-you-want-to-open-an-app-that-hasnt-been-notarized-or-is-from-an-unidentified-developer). You can also build a copy on your own Mac using the steps below. After an update, macOS may ask you to enable Accessibility again.

To start FtoA when you log in, add it under **System Settings → General → Login Items & Extensions → Open at Login**. If you used the SVG Bridge prototype, quit it and remove its login entry before switching to FtoA.

## What to expect when you paste

Use the Figma Design desktop app with English menus and paste into an open Affinity document. If you switch apps before Figma finishes exporting, check the FtoA menu for **Vector Ready for Affinity**, then paste.

FtoA passes Figma's SVG through unchanged. Affinity imports ordinary paths as editable curves. Figma can outline text, and Affinity can render some effects differently. If you want to check a particular layer without FtoA, use **Edit → Copy As → Copy as SVG** in Figma, then press ⌘V in Affinity.

FtoA uses Accessibility to run Figma's Copy as SVG command. It keeps the transfer in memory and restores the original Figma clipboard when you leave Affinity, provided you haven't copied anything else.

## Build from source

Use the macOS Command Line Tools with Swift 6.2 or later. Run the following from Terminal.

```sh
git clone https://github.com/teodorik/figmatoaffinity.git
cd figmatoaffinity
./build.sh /Applications/FtoA.app
open /Applications/FtoA.app
```

Quit a running copy of FtoA before rebuilding into Applications. Run `./tests/smoke.sh` to check clipboard swapping and universal app signing.
