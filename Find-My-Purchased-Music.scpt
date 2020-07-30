JsOsaDAS1.001.00bplist00ÑVscript_-†function askUser(app, message, dialogButtons=['Yes', 'No'], dialogDefaultButton='No', withIcon=null) {
  /* Ask the user for input.
     app: An Application instance
     message: The message to display in the dialog (string)
     dialogButtons: An array of buttons to display in the dialog (array of strings)
     dialogDefaultButton: The button that will be active by default (string)
     withIcon: An optional icon to display (string). Valid values are 'stop', 'note' and 'caution'

     This function doesn't designate a Cancel button to ensure
     that the result is always one of the buttons. (If the user clicks
     the Cancel button, the function throws an error.)
  */

  const validIcons = ['stop', 'note', 'caution'];

  // Set the buttons and defaultButtons options
  let opts = {
    buttons: dialogButtons,
    defaultButton: dialogDefaultButton
  }

  // If withIcon is a valid value, set the withIcon option
  if (withIcon !== null && validIcons.indexOf(withIcon) !== -1) {
    opts['withIcon'] = withIcon;
  }

  let result = app.displayDialog(message, opts);
  return result['buttonReturned'];
}

function writeArraysToTsv(filePath, data) {
  /* Write an array of arrays to a file as lines of tab-separated values. 
     filePath: The full path to the output file (string)
     data: An array of arrays
  */

  /* openForAccess will fail if called from anything except currentApplication, so app must be set to
  Application.currentApplication() in order to write the output file. */
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  
  let errors = new Array();
  
    try {
      // Show progress
      Progress.totalUnitCount = data.length;
      Progress.completedUnitCount = 0;
      Progress.description = 'Creating output file...';
      Progress.additionalDescription = '';

      // Open the file and write the data to it, then close it.
      let openedFile = app.openForAccess(Path(filePath), { writePermission: true });

      // Write the comma-separated lines to the file
      for (let d=0;d<data.length;d++) {
        let tsvData = data[d].join('\t') + '\n';

        // After the first line, 1 must be added to EOF.
        // Otherwise the next line will overwrite the first character of the previous line.
        let addByte = (d > 0) ? 1 : 0;
        app.write(tsvData, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });

        Progress.completedUnitCount = d;
      }

      app.closeAccess(openedFile);

      return 'success';
    }
    catch (error) {
      errors.push(error);
      try {
        // Close the file
        app.closeAccess(openedFile);
      }
      catch (error) {
        errors.push(error);
      }
    }

  return errors;
}


function writeArraysToHTML(filePath, data, title) {
  /* Write an array of arrays to a file as as HTML table. 
     filePath: The full path to the output file (string)
     data: An array of arrays
     title: The text for the HTML document's <title> element (string)
  */

  /* openForAccess will fail if called from anything except currentApplication, so app must be set to
  Application.currentApplication() in order to write the output file. */
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  
  let errors = new Array();

  try {
    // Show progress
    Progress.totalUnitCount = data.length;
    Progress.completedUnitCount = 0;
    Progress.description = 'Creating output file...';
    Progress.additionalDescription = '';

    // Open the file and write the data to it, then close it.
    let openedFile = app.openForAccess(Path(filePath), { writePermission: true });

    let css = '<style type="text/css">' + 
              'table { border: 1px solid black; border-collapse: collapse; }\n' +
              'tr, th, td { border: 1px solid black; padding: 5px; }\n' +
              'th { background-color: #D8D8D8; }\n' + 
              '</style>\n';

    let html = `<html>\n<head>${css}<title>${title}</title></head>\n<body>\n`;
    app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) });

    html = '<table>\n<tr>\n';
    // 1 must be added to EOF, otherwise the next line will overwrite the first character of the previous line
    app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });

    // The column names are in row 0 of data
    html = data[0].map(d => `<th>${d}</th>`).join('\n');
    app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });
    
    html = '\n</tr>';
    app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });

    for (let d=1;d<data.length;d++) {
      html = '<tr>\n';
      // Remove any commas in the values
      html += data[d].map(d => '<td>' + d.replace(/"/g, '') + '</td>').join('\n');
      html += '\n</tr>\n';
      app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });

      Progress.completedUnitCount = d;
    }

    html = '</table>\n</body>\n</html>';
    app.write(html, { to: openedFile, startingAt: app.getEof(openedFile) + 1 });

    app.closeAccess(openedFile);

    return 'success';
  }
  catch (error) {
    errors.push(error);
    try {
      // Close the file
      app.closeAccess(openedFile);
    }
    catch (error) {
      errors.push(error);
    }
  }

return errors;
}

ObjC.import('stdlib');

const testedMajorVersions = [10];
const testedMinorVersions = [14, 15];

// Get the macOS version
let currentApp = Application.currentApplication();
currentApp.includeStandardAdditions = true;
const version = currentApp.systemInfo().systemVersion;
const majorVersion = parseInt(version.substring(0, 2)); // Get only the major version, e.g., 10
const minorVersion = parseInt(version.substring(3, 5)); // Get only the minor version, e.g., 15

// Warn the user if running the script on an untested version of macOS
if (testedMajorVersions.indexOf(majorVersion) === -1 || testedMinorVersions.indexOf(minorVersion) === -1) {
  let message = `This script hasn't been tested on macOS version ${version}, and it may not work. Do you want to continue or exit?`;
  let userDecision = askUser(currentApp, message, ['Continue', 'Exit'], 'Exit', 'caution');

  // If the user clicks the Exit button, exit the script. Otherwise just continue as usual.
  if (userDecision === 'Exit') {
    $.exit(0);
  }
}

// Get the appropriate music app
let musicApp;
try {
  musicApp = Application('Music');
}
catch (error) {
  try {
    musicApp = Application('iTunes');
  }
  catch (error) {
    let message = 'Error: Unable to locate Music or iTunes. Script will exit.'
    askUser(currentApp, message, ['OK'], 'OK', 'stop');
    $.exit(0);
  }
}

musicApp.includeStandardAdditions = true;

// Get the date
const today = new Date();
const month = (today.getMonth() + 1).toString().padStart(2, '0');
const day = today.getDate().toString().padStart(2, '0');
const hours = today.getHours().toString().padStart(2, '0');
const minutes = today.getMinutes().toString().padStart(2, '0');
const seconds = today.getSeconds().toString().padStart(2, '0');
const fileDate = today.getFullYear() + '-' + month + '-' + day + '-' + hours + minutes + seconds;

// Get all playlists. Filter out all whose names start with 'Purchased' since they likely contain only purchased music.
const playlists = musicApp.playlists().filter(p => !p.name().toLowerCase().startsWith('purchased'));

// Create an array of the playlist names to present to the user for selection
const playlistsForSelection = playlists.map(p => p.name());

let noSelection = true;
let selectedPlaylists;

// Prompt the user to select one or more playlists
while (noSelection === true) {
  selectedPlaylists = musicApp.chooseFromList(playlistsForSelection, {withPrompt: 'Choose one or more playlists to analyze. (Choose "Library" or "Music" to analyze all songs.)', multipleSelectionsAllowed: true});

  if (selectedPlaylists === false) {
    // If no selection was made, ask the user if they want to exit
    result = askUser(musicApp, 'No playlist selected. Do you want to quit?');

    // If the user clicks 'Yes', break out of the while loop so that the script will quit.
    // Else the loop will just repeat.
    if (result === 'Yes') {
      $.exit(0);
    }
  }
  else {
    // If a selection was made, set the control variable to false to stop the while loop
    noSelection = false;
  }
}

// Ask the user for the output format and set the full path of the output file
const outputFormat = askUser(musicApp, 'Do you want to output the list as a TSV (tab-separated values) file or an HTML file?', ['HTML', 'TSV'], 'HTML');
const fileExtension = outputFormat.toLowerCase();

var newFilePath = musicApp.chooseFileName({
  withPrompt: 'Enter a name for the output file (the extension will be added automatically).'
})

const outputFilePath = `${newFilePath}.${fileExtension}`;

// Get the tracks in each playlist
let tracks = {};

for (let sp of selectedPlaylists) {
  tracks[sp] = musicApp.playlists[sp].tracks();
}


// Get the name, artist, album and status (purchased or cloud) of each track
let allTrackInfo = {};

for (let property in tracks) {
  let playlistTracks = {};
  let trackCount = tracks[property].length;

  // Show progress
  Progress.totalUnitCount = trackCount;
  Progress.completedUnitCount = 0;
  Progress.description = `Analyzing ${trackCount} tracks in playlist "${property}"...`;
  Progress.additionalDescription = '';

  for (t=0;t<trackCount;t++) {
    let trk = tracks[property][t];
    let trackInfo = {};

    // Quote each value in case it contains commas
    name = trk.name();
    trackInfo['Name'] = name;
    trackInfo['Artist'] = trk.artist();
    trackInfo['Album'] = trk.album();
    trackInfo['Kind'] = trk.kind();
    trackInfo['Cloud Status'] = trk.cloudStatus();
    
    if (trk.cloudStatus() == 'purchased' || trk.cloudStatus() == 'matched' || trk.cloudStatus() == 'uploaded') {
      trackInfo['Purchased'] = 'Yes';
    }
    else if (trk.cloudStatus() == 'subscription') {
      trackInfo['Purchased'] = 'No';
    }
    else {
      trackInfo['Purchased'] = 'Unknown';
    }

    playlistTracks[name] = trackInfo;

    Progress.completedUnitCount = t;
  }
  allTrackInfo[property] = playlistTracks;
}

console.log('Done');

let sortedAllTrackKeys = Object.keys(allTrackInfo).sort();

const outputHeaders = ['Playlist', 'Song', 'Artist', 'Album', 'Purchased', 'Kind', 'Cloud Status'];
let outputData = new Array();
outputData.push(outputHeaders);

for (playlistName of sortedAllTrackKeys) {
  let currentPlaylist = allTrackInfo[playlistName];
  let sortedTrackInfoKeys = Object.keys(currentPlaylist).sort();
  
  for (i of sortedTrackInfoKeys) {
    outputTrackInfo = currentPlaylist[i];
    trackData = [playlistName, outputTrackInfo['Name'], outputTrackInfo['Artist'], outputTrackInfo['Album'], outputTrackInfo['Purchased'], outputTrackInfo['Kind'], outputTrackInfo['Cloud Status']];
    outputData.push(trackData);
  }
}

let writeResult;

if (outputFormat === 'TSV') {
  writeResult = writeArraysToTsv(outputFilePath, outputData);
}
else {
  writeResult = writeArraysToHTML(outputFilePath, outputData, `Purchased Music: ${fileDate}`);
}

if (writeResult !== 'success') {
  let errorMessage = `Error writing data to file ${outputFilePath}.\nThe following error(s) occurred:\n`;
  errorMessage += writeResult.join('\n');
  const errorResult = musicApp.displayDialog(errorMessage, {
    buttons: ['OK'],
    defaultButton: 'OK',
    withIcon: 'caution'
  });
}
else {
  const errorResult = musicApp.displayDialog(`Music data output to ${outputFilePath}`, {
    buttons: ['OK'],
    defaultButton: 'OK'
  });
}

$.exit(0);                              -œjscr  úÞÞ­