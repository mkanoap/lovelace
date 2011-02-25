/*
  Lovelace brain - sound lobe
  v 1.1
*/

// library for showing free memory.
#include <MemoryFree.h>

// library for program space
#include <avr/pgmspace.h>

// waveRP libraries for playing wave files
#include <mcpDac.h>
#include <pin_to_avr.h>
#include <WaveRP.h>
#include <WaveStructs.h>

// sdcard libraries
#include <SdFat.h>
#include <Sd2Card.h>
//#include "PgmPrint.h" ... functionality appears in sdFatUtil.h
#include <SdFatUtil.h>
#include <ctype.h>

// I/O Configuration //
#define CS 6   // blue wire
#define MISO 7 // orange wire
#define MOSI 8 // green wire
#define SCK  9 // yellow wire

// number of sounds
#define numsounds 181

// buttonpad globals
byte lights[3][16]; // [3] = Red, Blue, Green // array that holds all the light values
int unsigned buttons = 0;

// wav global variables
Sd2Card card;           // SD/SDHC card with support for version 2.00 features
SdVolume volume;           // FAT16 or FAT32 volume
SdFile root;            // volume's root directory
//SdFile kns;             // k9 sound files, by number
SdFile dirfile;           // subdirectory file (kns=sounds, num=digets)
SdFile soundfile;        // the file to play
WaveRP wave;

byte ledPin = 6;  // When a sound is played, turn on LED
byte randPin = 6; // this is the analog pin used for random numbers

// program global variables
const byte bufferLength = 12;
char buffer[bufferLength];      // serial input buffer
byte bufferPos = 0; 
byte rn=0;
String soundindex;
char soundtoplay[bufferLength];
char c; // character read at any particular point in time
uint8_t i; // i is used for loops

/*
 Create the arrays that will hold the group info.
 Stick them into program memory for arcane manipulation to save ram.
 Put a 0 byte at the end (wasting 16 bytes) so they can be manipulated by string functions
*/
prog_uchar g1array[] PROGMEM = {12,13,34,0};
prog_uchar g2array[] PROGMEM = {82,108,109,0};
prog_uchar g3array[] PROGMEM = {91,92,93,94,95,0};
prog_uchar g4array[] PROGMEM = {103,104,105,106,107,0};
prog_uchar g5array[] PROGMEM = {22,24,49,86,98,112,115,117,141,142,146,162,166,179,0};
prog_uchar g6array[] PROGMEM = {23,0};
prog_uchar g7array[] PROGMEM = {28,34,0};
prog_uchar g8array[] PROGMEM = {75,0};
prog_uchar g9array[] PROGMEM = {59,77,0};
prog_uchar g10array[] PROGMEM = {180,0};
prog_uchar g11array[] PROGMEM = {42,120,0};
prog_uchar g12array[] PROGMEM = {152,0};
prog_uchar g13array[] PROGMEM = {147,0};
prog_uchar g14array[] PROGMEM = {175,176,0};
prog_uchar g15array[] PROGMEM = {122,0};
prog_uchar g16array[] PROGMEM = {16,18,19,20,27,30,31,32,38,39,41,51,53,56,57,60,83,113,118,127,128,131,135,145,148,151,153,160,163,168,172,0};
// create a table that is an array of pointers to the arrays in program memory
const prog_uchar* group_table[] PROGMEM = {g1array,g2array,g3array,g4array,g5array,g6array,g7array,g8array,g9array,g10array,g11array,g12array,g13array,g14array,g15array,g16array};

boolean b = 0;

/*
     button functions 
*/
// randomize the buttons
void randomize() {
  for(int f = 0; f < 3; f++) {// cycle through the frames
    for(int i = 0; i < 16; i++) { // cycle through the buttons
      lights[f][i]=random(10);
    } // end of buttons loop
  } // end of frame loop
} // end of randomize

// reset the buttons to default
void setbuttons() {
  lights[0][0]=10; lights[1][0]=0;lights[2][0]=0; // red
  lights[0][1]=0; lights[1][1]=10;lights[2][1]=0; // green
  lights[0][2]=0; lights[1][2]=0;lights[2][2]=10; // blue
  lights[0][3]=10; lights[1][3]=0;lights[2][3]=0; // violet
  lights[0][4]=10; lights[1][4]=0;lights[2][4]=10; // yellow
  lights[0][5]=0; lights[1][5]=10;lights[2][5]=10; // light blue
  lights[0][6]=10; lights[1][6]=10;lights[2][6]=10; // white
  lights[0][7]=10; lights[1][7]=2;lights[2][7]=2; // ???
  lights[0][8]=3; lights[1][8]=3;lights[2][8]=0; // purple
  lights[0][9]=7; lights[1][9]=0;lights[2][9]=2; // orange
  lights[0][10]=0; lights[1][10]=6;lights[2][10]=3; // blueish
  lights[0][11]=2; lights[1][11]=0;lights[2][11]=8; // lime
  lights[0][12]=10; lights[1][12]=0;lights[2][12]=0; // red
  lights[0][13]=0; lights[1][13]=0;lights[2][13]=4; // emerald
  lights[0][14]=10; lights[1][14]=10;lights[2][14]=0; // violet
  lights[0][15]=10; lights[1][15]=0;lights[2][15]=0; // red
  PgmPrintln("buttons reset");
}

// update the buttons with current colors, and read in button press values
void buttonpadrw() {
  digitalWrite(SCK, HIGH);
  digitalWrite(CS, HIGH); // bring up the clock select pin, to start reading/writing
  delayMicroseconds(15);

  for(byte f = 0; f < 4; f++) { // cycle through the frames, Red, Blue, Green and "button read"
      for(int i = 0; i < 16; i++) { // cycle through the buttons, one byte each
        if (bitRead(buttons,i)==1) { // if a button is marked as "pressed" from previous iteration
          lights[f][i] = 10;  // a held down button is white
        }
        for(int ii = 0; ii < 8; ii++) { // cycle through the bits in a single byte
          digitalWrite(SCK, LOW); // bring down clock pin and ...
          delayMicroseconds(5); // ... wait 5 microseconds

          if (f < 3) { // for the three color frames... 
            digitalWrite(MISO, bitRead(lights[f][i],ii)); // ...write out the colors by flipping the MISO pin
          } else if (ii == 0) { // for the fourth frame...
            b = abs(digitalRead(MOSI)-1); // ... ignore MISO and instead read the MOSI pin
            bitWrite(buttons,i,b); // note the buttons
          }
          delayMicroseconds(5);
          digitalWrite(SCK, HIGH); // after waiting 5 microseconds, bring the clock pin up...
          delayMicroseconds(10); // ... wait 10 microseconds...
        } // ... finish up the byte loop
      } // finish the button loop
  } // finish the all the writing
  digitalWrite(CS, LOW); // bring clock select pin down, because we are finished.

  delayMicroseconds(400);
  delay(10);

buttons = 0; // just for debugging, delete me if plugged into a button pad

  if (buttons >0) {
    PgmPrint("buttons:'");
    Serial.println(buttons);
  }
}
/*
   sound routines
*/
// play a file by name, from provided directory
void playFile(char * name, char * dirname) {
  PgmPrint("Getting ready to play: ");Serial.print(name);
  if (!dirfile.open(&root, dirname, O_READ)) {
        PgmPrintln("Can't open directory."); 
        dirfile.close();
        return;
  }
  if (!soundfile.open(dirfile, name)) {
    PgmPrint("Can't open: ");
    Serial.println(name);
    return;
  }
  if (!wave.play(&soundfile)) {
    PgmPrint("Can't play: ");Serial.println(name);
    soundfile.close();
    return;
  }
  PgmPrint("Playing: ");Serial.print(name);
  digitalWrite(ledPin, HIGH);

  while (wave.isPlaying()) {
    // do nothing
    delay(50);
    Serial.print(".");
  }
  soundfile.close();
  dirfile.close();
  digitalWrite(ledPin, LOW);
  PgmPrintln("Done playing, soundfile closed.");
}

/*
// play a clip described by name
*/
void speak (String numtoplay) { // play a clip if you have 
    soundindex = "KNS"; // start off by setting the start of the file name
    soundindex=soundindex + numtoplay + ".WAV";  // finish off by adding the extention
    PgmPrint("playing sound file: ");
    Serial.println(soundindex);
    soundindex.toCharArray(soundtoplay,bufferLength); // lame convert from string back into char
    playFile(soundtoplay, "kns");
}

/*
// play a sound described by a number
*/
void speak_by_num(int numtoplay) {
  speak (String(numtoplay));
}

/*
// say a number in natural language
*/
void parse_number(float numtosay) {
  PgmPrint(" parsing number: ");
  Serial.println(numtosay);
  int num;
  if (numtosay < 0) { // maybe it's a negative number.  If so, note that and then treat it as positive
    speak_num("n"); // say "negative"
    numtosay=abs(numtosay);
  }
  if (numtosay >= 1e12) { // =1,000,000,000,000 or one trillion in scientific notation
    num=numtosay/1e12;
    hundreds(num); // call hundreds to speak these three
    speak_num("tr"); // say "trillion"
    numtosay=numtosay-(num* 1e12);
  }
  if (numtosay >= 1e9) { // =1,000,000,000 or one billion in scientific notation
    num=numtosay/1e9;
    hundreds(num); // call hundreds to speak these three
    speak_num("b"); // say "billion"
    numtosay=numtosay-(num * 1e9);
  }
  if (numtosay >= 1e6) { // =1,000,000 or one million in scientific notation
    num=numtosay/1e6;
    hundreds(num); // call hundreds to speak these three
    speak_num("m"); // say "million"
    numtosay=numtosay-(num*1e6);
  }
  if (numtosay >= 1e3) { // =1,000 or one thousand in scientific notation
    num=numtosay/1e3;
    hundreds(num); // call hundreds to speak these three
    speak_num("t"); // say "thousand"
    numtosay=numtosay-(num * 1e3);
  }
  hundreds(numtosay);  // say whatever is left before the zero
  numtosay=numtosay - (int) numtosay; // trim off anything before the zero.
  if (numtosay > 0 ) { // maybe there is a fraction to say
    speak_num("p"); // say "point"
    numtosay=numtosay*10;
    while (numtosay > 0) { // just loop until the number is done, hope it isn't repeating
      speak_num(String((int)numtosay));
      numtosay=numtosay-int(numtosay);
      numtosay=numtosay*10;
    } // end of while loop
  } // end of fractions
} // end of number parse

// speak a number from 0-999, calling the tens as needed
void hundreds(int numtosay) {
  int num;
  if (numtosay > 99 ) { // we need to say the hundreds place
    num = (numtosay/100); // get just the hundreds diget
    speak_num(String(num)); // say the digit
    speak_num("h"); // say "hundred"
  } // end of "bigger than 99"
  if ((numtosay % 100) > 0 ) { // if it's not an even hundred
    tens(numtosay % 100); // call the tens function to finish it up
  }
}

// speak a number from from 0-99, called from other functions, never with larger than 99
void tens(int numtosay) {
  int num;
  if (numtosay > 19 ) { // do for the bigger numbers
    num = ((numtosay/10)*10); // convert 23 to 20, 42 to 40, etc.
    speak_num(String(num));
    if ((numtosay % 10) > 0) { // speak the remainder, if any.
      speak_num(String(numtosay % 10));
    } // end of remainder condition
  } else { // end of bigger number condition, so speak the smaller numbers
    speak_num(String(numtosay)); // remaining condition should be 0-19, which we have files for
  }
}

// speak a particular sound number file.
void speak_num(String numtoplay) {
    soundindex=numtoplay + ".WAV";  // add the extention
    PgmPrint("playing number file: ");
    Serial.println(soundindex);
    soundindex.toCharArray(soundtoplay,bufferLength); // lame convert from string back into char
    playFile(soundtoplay, "num");  
}

// pick a random element from an array, old version to be deleted
byte rand_array_old(byte r_array[], byte r_size) {
  byte randNumber= random(r_size);
  Serial.println(randNumber);
  return r_array[randNumber];
}
// pick a random element from an array
byte rand_array(byte rindex) {
  // get the length of array in progmem who's position in the table is "index"
  byte r_size= strlen_P((PGM_P)pgm_read_word(&group_table[rindex])); 
Serial.print("r_size: ");Serial.println((int)r_size);
  byte randNumber= random(r_size);
  Serial.println((int)randNumber);
  // copy one byte from the array in progmem who's postion in the table is "index", ofset by randNumber
  byte r_result;
  memcpy_P(&r_result, (PGM_P)pgm_read_word(&group_table[rindex])+randNumber, 1);
  return r_result;
}

/*
*
*    setup() is run once when arduino is first reset
*
*/
void setup() {                   // run once, when the sketch starts
  // set up the pins used for buttonpad
  pinMode(CS, OUTPUT);
  pinMode(MISO, OUTPUT);
  pinMode(MOSI, INPUT);
  pinMode(SCK, OUTPUT);

  digitalWrite(CS, LOW);
  delay(1);
  
  Serial.begin(9600);
  PgmPrintln("K9 sound module");
  PgmPrint("freeMemory()=");
  Serial.println(freeMemory());

byte testbyte;
int testlength = strlen_P((PGM_P)pgm_read_word(&group_table[15]));
Serial.println((int)testlength);
i=0;
while (i<testlength) {
  memcpy_P(&testbyte, (PGM_P)pgm_read_word(&group_table[15])+i, 1);
  Serial.print((int)testbyte);
  Serial.print(", ");
  i++;
}

  pinMode(ledPin, OUTPUT);
  randomSeed(analogRead(randPin)); 
  if (!card.init()) {
    PgmPrintln("Card init. failed!"); 
  }
  if (!volume.init(&card)) {
    PgmPrintln("No partition!"); 
  }
  if (!root.openRoot(&volume)) {
        PgmPrintln("Can't open root dir"); 
  }
//  if (!kns.open(&root, "kns", O_READ)) {
//        PgmPrintln("Can't open KNS dir"); 
//  }

  PgmPrintln("Incomming Data");
//  playFile("start.wav");

// set the buttons to the initial state
  setbuttons();
  buttonpadrw();

} // end of setup()
/*
*
*    Main loop, all the code runs here
*
*/
void loop() { // main program
    Serial.print("freeMemory()=");
    Serial.println(freeMemory());

  bufferPos=0;
  c=0;
  while ( c!= '\n' && c!= '\r' ) { // read in a line, stop reading when a return or newline is sent
    if ( Serial.available()) { // only try to grab a character if there is one in the buffer
      c = Serial.read(); // read in a single character
      if (c!= '\n' && c!= '\r') { // if it's not the end
        buffer[bufferPos++] = c; // add it to the end of the buffer
      } else { // received CR or LF
        buffer[bufferPos]=0; // terminate the string
      }
      delay(10);
    } // end of "if serial.available
    buttonpadrw(); // update the button pad and read in the buttons
    if (buttons > 0) { // a button has been pushed
      randomize(); // randomize the colors
      c='\n'; // act like a newline was received.
      switch (buttons) {
        case 1: // 1
          strcpy(buffer,"g1");
          setbuttons();
          break;
        case 2: // 2
          strcpy(buffer,"g2");
          break;
        case 4: // 3
          strcpy(buffer,"g3");
          break;
        case 8: // 4
          strcpy(buffer,"g4");
          break;
        case 16: // 5
          strcpy(buffer,"g5");
          break;
        case 32: // 6
          strcpy(buffer,"g6");
          break;
        case 64: // 7
          strcpy(buffer,"g7");
          setbuttons();
          break;
        case 128: // 8
          strcpy(buffer,"g8");
          break;
        case 256: // 9
          strcpy(buffer,"g9");
          break;
        case 512: // 10
          strcpy(buffer,"g10");
          break;
        case 1024: // 11
          strcpy(buffer,"g11");
          break;
        case 2048: // 12
          strcpy(buffer,"g12");
          break;
        case 4096: // 13
          strcpy(buffer,"g13");
          break;
        case 8192: // 14
          strcpy(buffer,"g14");
          break;
        case 16384: // 15
          strcpy(buffer,"g15");
          break;
        case 32768: // 16
          strcpy(buffer,"g16");
          break;


      } // end of button switch
      PgmPrint("buffer = '");
      Serial.println(buffer);
    } // end of button press
  } // end of "not end of line
// grab all but the first character as a string for use in different commands
  i=1;
  soundindex = "";
  while (buffer[i] != 0 && i < 12) { // make soundindex be the rest of the digits
    soundindex = soundindex + buffer[i];
    i++;
  } // end of soundindex string construction

  if (buffer[0]=='p') { // if the first character is p, it's a play command
    speak(soundindex);
  } else if (buffer[0]=='n') { // they asked for a number to be parsed
    parse_number((float)soundindex.toInt());
  } else if (buffer[0]=='g') { // they asked for random sound from a group
      Serial.println(soundindex);
      rn=rand_array(soundindex.toInt()-1); // pick random number from the array one less than the group number
      speak_by_num(rn);
//      Serial.println((int) rn);
  } else if (buffer[0]=='r') { // they asked for a random sound
    rn = random(numsounds)+1; // pick a random number from 1 - numsounds
    speak_by_num(rn);
  } else if (bufferPos > 0 ) {
    PgmPrint("received unknown command:");
    Serial.println(buffer);
  }
} // end of loop()


