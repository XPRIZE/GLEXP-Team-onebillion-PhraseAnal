# PhraseAnal


## About
PhraseAnal is a macOS utility for creating timing metadata from an audio file and outputting it to an `.epta` xml file. This metadata contains timing  _segments_ used as sync points by another application. For example, the start of a syllable or letter sound.


## Building and Installing
Clone this repository, open `PhraseAnal.xcodeproj` in Xcode, build and run.


## Usage

### Opening an audio file
Drag an audio file into the default window, or choose _File &rarr; Import Audio_. The window shows a graphic representation of the audio waveform. Zoom in using <kbd>alt</kbd> + <kbd>command</kbd> and clicking. Zoom out with <kbd>shift</kbd> + <kbd>alt</kbd> + <kbd>command</kbd> and clicking.
Listen to the audio by pressing <kbd>space</kbd> or clicking on the play arrow. A red line moves showing the current play position.

### Manually marking segments

Use the segment bar below the waveform to manually define segments which represent areas of interest in the sound file. For example, consider the English audio file `fc_let_kick.m4a` which is a recording of the word _kick_ split into phonemes: _k_, _i_, and _ck_, with a gap between each. In this simple case, the waveform shows three areas with significant amplitude, with gaps of silence between them. Define a segment for each of the three areas.


### Automatically marking segments with autosplit
In the bottom-right of the PhraseAnal window is a text box.
To automatically mark the segments in the 'kick' example, enter the phonemes delimited by spaces: _'k i ck'_. Choose _Edit &rarr; Autosplit_. PhraseAnal will attept to automatically create three segments in the segment bar, each having a green start arrow and a red ending area. Drag the areas and the arrows to manually fine-tune each segment.

Play a segment by clicking on it. Edit by right clicking.

### Saving segments to an .etpa file
Once all segments have been marked, choose _File &rarr; Save_ or _Save As_ to save the `.etpa` xml file. It will contain the start and end time of each segment in seconds. The `.etpa` file can be edited again by opening it with PhraseAnal.



