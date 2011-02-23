// Manual control of the Button Pad Controller SPI.
// Based on documentation at
// http://www.sparkfun.com/datasheets/Widgets/ButtonPadControllerSPI_UserGuide_v2.pdf
//
// Original code By Havard Rast Blok, 2010.
// Updated by WilliamK @ Wusik Dot Com - http://arduino.wusik.com - (c) 2011

// I/O Configuration //
#define CS 6   // blue
#define MISO 7 // orange
#define MOSI 8 // green
#define SCK  9 // yellow


byte lights[3][16]; // [3] = Red, Blue, Green //
int unsigned buttons = 0;

void randomize() {
  for(int f = 0; f < 3; f++) {// cycle through the frames
    for(int i = 0; i < 16; i++) { // cycle through the buttons
      lights[f][i]=random(10);
    } // end of buttons loop
  } // end of frame loop
} // end of randomize

void setup() { 
  pinMode(CS, OUTPUT);
  pinMode(MISO, OUTPUT);
  pinMode(MOSI, INPUT);
  pinMode(SCK, OUTPUT);

  digitalWrite(CS, LOW);
  delay(1);
  Serial.begin(9600);

  memset(lights,0,sizeof(lights)); // turn off all the buttons
//  randomize();
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
}

void loop() {
    Serial.print("buttons:"); 
    Serial.println(buttons,DEC);
  if (buttons > 0) {
    randomize();
  }
  digitalWrite(SCK, HIGH);
  digitalWrite(CS, HIGH);
  delayMicroseconds(15);

  for(int f = 0; f < 4; f++) { // cycle through the frames
      for(int i = 0; i < 16; i++) {
        if (bitRead(buttons,i)==1) {
          lights[f][i] = 10;
        }
//        lights[f][i] = bitRead(buttons,i) ? 0 : 10; // lights up when button pressed //
        for(int ii = 0; ii < 8; ii++) {
          digitalWrite(SCK, LOW);
          delayMicroseconds(5);

          if (f < 3) {
            digitalWrite(MISO, bitRead(lights[f][i],ii)); // write out the colors
          } else if (ii == 0) {
            bitWrite(buttons,i,abs(digitalRead(MOSI)-1)); // note the buttons
          }
          delayMicroseconds(5);

          digitalWrite(SCK, HIGH);
          delayMicroseconds(10);
        }
      }
  }

  digitalWrite(CS, LOW);

  delayMicroseconds(400);
  delay(10);
}

