#include <Servo.h>
Servo myservo;

char Incoming_value = 0; 
int pos=80;

void setup() 
{
  Serial.begin(9600);        
  pinMode(8, OUTPUT);       
  myservo.attach(9);
  myservo.write(65); 
}
void loop()
{             
  if(Serial.available() > 0)  
  {
    Incoming_value = Serial.read();         //Read the incoming data 
    
    if(Incoming_value == '1')               // for locking solenoid lock
      digitalWrite(8, HIGH);  
    else if(Incoming_value == '0')          // for unlocking solenoid lock
      digitalWrite(8, LOW);   
    else if(Incoming_value == '4')          // for open door using servo motor
    {
      for (; pos >=-65; pos -= 1) {
        myservo.write(pos);                    
        delay(10);
      }
    }
    else if(Incoming_value == '3')          // for close door using servo motor
    {
      for (; pos <=65; pos += 1) {
        myservo.write(pos);                    
        delay(10);
      }  
    }  
  }
}  
