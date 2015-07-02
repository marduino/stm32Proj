/******************************************************************************************
* Test Sketch for Razor AHRS v1.4.2
* 9 Degree of Measurement Attitude and Heading Reference System
* for Sparkfun "9DOF Razor IMU" and "9DOF Sensor Stick"
*
* Released under GNU GPL (General Public License) v3.0
* Copyright (C) 2013 Peter Bartz [http://ptrbrtz.net]
* Copyright (C) 2011-2012 Quality & Usability Lab, Deutsche Telekom Laboratories, TU Berlin
* Written by Peter Bartz (peter-bartz@gmx.de)
*
* Infos, updates, bug reports, contributions and feedback:
*     https://github.com/ptrbrtz/razor-9dof-ahrs
******************************************************************************************/

/*
  NOTE: There seems to be a bug with the serial library in Processing versions 1.5
  and 1.5.1: "WARNING: RXTX Version mismatch ...".
  Processing 2.0.x seems to work just fine. Later versions may too.
  Alternatively, the older version 1.2.1 also works and is still available on the web.
*/

import processing.opengl.*;
import processing.serial.*;

// IF THE SKETCH CRASHES OR HANGS ON STARTUP, MAKE SURE YOU ARE USING THE RIGHT SERIAL PORT:
// 1. Have a look at the Processing console output of this sketch.
// 2. Look for the serial port list and find the port you need (it's the same as in Arduino).
// 3. Set your port number here:
final static int SERIAL_PORT_NUM = 1;
// 4. Try again.


final static int SERIAL_PORT_BAUD_RATE = 225000;//460800;

float yaw = 0.0f;
float pitch = 0.0f;
float roll = 0.0f;
float yawOffset = 0.0f;
float pitchOffset = 0.0f;
float rollOffset = 0.0f;

PFont font;
Serial serial;

boolean synched = false;

float[] ypr;

void drawArrow(float headWidthFactor, float headLengthFactor) {
  float headWidth = headWidthFactor * 200.0f;
  float headLength = headLengthFactor * 200.0f;
  
  pushMatrix();
  
  // Draw base
  translate(0, 0, -100);
  box(100, 100, 200);
  
  // Draw pointer
  translate(-headWidth/2, -50, -100);
  beginShape(QUAD_STRIP);
    vertex(0, 0 ,0);
    vertex(0, 100, 0);
    vertex(headWidth, 0 ,0);
    vertex(headWidth, 100, 0);
    vertex(headWidth/2, 0, -headLength);
    vertex(headWidth/2, 100, -headLength);
    vertex(0, 0 ,0);
    vertex(0, 100, 0);
  endShape();
  beginShape(TRIANGLES);
    vertex(0, 0, 0);
    vertex(headWidth, 0, 0);
    vertex(headWidth/2, 0, -headLength);
    vertex(0, 100, 0);
    vertex(headWidth, 100, 0);
    vertex(headWidth/2, 100, -headLength);
  endShape();
  
  popMatrix();
}

void drawBoard() {
  pushMatrix();

  rotateY(radians(yaw - yawOffset));
  rotateZ(radians(pitch - pitchOffset));
  rotateX(-radians(roll - rollOffset)); 

  // Board body
  fill(255, 0, 0);
  box(250, 20, 400);
  
  // Forward-arrow
  pushMatrix();
  translate(0, 0, -200);
  scale(0.5f, 0.2f, 0.25f);
  fill(0, 255, 0);
  drawArrow(1.0f, 2.0f);
  popMatrix();
    
  popMatrix();
}

// Skip incoming serial stream data until token is found
boolean readToken(Serial serial, String token) {
  /*
  // Wait until enough bytes are available
  if (serial.available() < token.length())
    return false;
  
  String str = serial.readStringUntil('\n');
  if (null == str)
  {
    return false;
  }
  println("Get reply:" + str + "expect:"+token);
  // Check if incoming bytes match token
  for (int i = 0; i < token.length(); i++) {
    if (str.charAt(i) != token.charAt(i))
      return false;
  }
  
  println("sync success!");*/
  return true;
}

// Global setup
void setup() {
  // Setup graphics
  size(640, 480, OPENGL);
  smooth();
  noStroke();
  frameRate(120);
  
  // Load font
  font = loadFont("Univers-66.vlw");
  textFont(font);
  
  // Setup serial port I/O
  println("AVAILABLE SERIAL PORTS:");
  println(Serial.list());
  String portName = "COM8";//Serial.list()[SERIAL_PORT_NUM];
  println();
  println("HAVE A LOOK AT THE LIST ABOVE AND SET THE RIGHT SERIAL PORT NUMBER IN THE CODE!");
  println("  -> Using port " + SERIAL_PORT_NUM + ": " + portName);
  serial = new Serial(this, portName, SERIAL_PORT_BAUD_RATE);
}

void setupRazor() {
  println("Trying to setup and synch Razor...");
  
  // On Mac OSX and Linux (Windows too?) the board will do a reset when we connect, which is really bad.
  // See "Automatic (Software) Reset" on http://www.arduino.cc/en/Main/ArduinoBoardProMini
  // So we have to wait until the bootloader is finished and the Razor firmware can receive commands.
  // To prevent this, disconnect/cut/unplug the DTR line going to the board. This also has the advantage,
  // that the angles you receive are stable right from the beginning. 
  delay(300);  // 3 seconds should be enough
  
  // Set Razor output parameters
//  serial.write("#ob\r");  // Turn on binary output
  serial.write("orien\r\n");  // Turn on continuous streaming output
//  serial.write("orienlog\r"); // Turn on orientation log
  delay(300);
  // Synch with Razor
//  serial.clear();  // Clear input buffer up to here
//  serial.write("#sync 00\r");  // Request synch token
}

float readFloat(Serial s) {
  // Convert from little endian (Razor) to big endian (Java) and interpret as float
  return Float.intBitsToFloat(s.read() + (s.read() << 8) + (s.read() << 16) + (s.read() << 24));
}

boolean updateYPR(Serial s)
{
  if (s.available() <= 0)
    return false;
  
  String str = s.readStringUntil('\n');
  if (null == str)
  {
    return false;
  }

  println("recv:" + str);
  String[] m = match(str, "#YPR=(.*?)");
  if (null == m)
  {
    return false;
  }
  
  m = split(str, '=');
  ypr = float(split(m[1], ','));
//  println("ypr:" + ypr[0] + ypr[1] + ypr[2]);
  return true;
}

void draw() {
   // Reset scene
  background(0);
  lights();


  // Sync with Razor 
  if (!synched) {
    textAlign(CENTER);
    fill(255);
    text("Connecting to FlyDragon...", width/2, height/2, -200);
    
    if (frameCount == 2)
      setupRazor();  // Set ouput params and request synch token
    else if (frameCount > 2)
      synched = readToken(serial, "#SYNCH00");  // Look for synch token
    return;
  }
 
  // Read angles from serial port
  /*
  while (serial.available() >= 12) {
    yaw = readFloat(serial);
    pitch = readFloat(serial);
    roll = readFloat(serial);
  }*/
  while(false == updateYPR(serial));

  yaw = ypr[0];
  pitch = ypr[1];
  roll = ypr[2];

  // Draw board
  pushMatrix();
  translate(width/2, height/2, -350);
  drawBoard();
  popMatrix();
  
  textFont(font, 20);
  fill(255);
  textAlign(LEFT);

  // Output info text
  text("Point FTDI connector towards screen and press 'a' to align", 10, 25);

  // Output angles
  pushMatrix();
  translate(10, height - 10);
  textAlign(LEFT);
  text("Yaw: " + ((int) (yaw - yawOffset)), 0, 0);
  text("Pitch: " + ((int) (pitch - pitchOffset)), 150, 0);
  text("Roll: " + ((int) (roll - rollOffset)), 300, 0);
  popMatrix();
  
}

void keyPressed() {
  switch (key) {
    case '1':  // Turn on orientation out put
      println("turn on");
      serial.write("orien on\r\n");
      break;
    case '2':  // Turn on orientation out put
      serial.write("orien off\r\n");
      break;
    case '3':  // Turn Razor's continuous output stream on
      serial.write("#o1\r");
      break;
    case '4':  // Request one single yaw/pitch/roll frame from Razor (use when continuous streaming is off)
      serial.write("#f\r");
      break;
    case 'a':  // Align screen with Razor
      yawOffset = yaw;
      pitchOffset = pitch;
      rollOffset = roll;
  }
}



