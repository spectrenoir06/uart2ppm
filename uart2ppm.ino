#define CHANNEL_NUMBER 6
#define CHANNEL_DEFAULT_VALUE 1500
#define FRAME_LENGTH 40000
#define PULSE_LENGTH 397
#define onState 0
#define sigPin 12
#define gndPin 11

// min = 0.600; max = 1.600
// pulse 0.

uint16_t ppm[CHANNEL_NUMBER];

int currentChannelStep;

void setup(){
	Serial.begin(115200);
	for(int i=0; i<CHANNEL_NUMBER; i++)
		ppm[i]= CHANNEL_DEFAULT_VALUE;

	pinMode(sigPin, OUTPUT);
	pinMode(gndPin, OUTPUT);
	digitalWrite(sigPin, !onState);
	digitalWrite(gndPin, LOW);

	cli();
	TCCR1A = 0; // set entire TCCR1 register to 0
	TCCR1B = 0;

	OCR1A = 100;  // compare match register, change this
	TCCR1B |= (1 << WGM12);  // turn on CTC mode
	TCCR1B |= (1 << CS11);  // 8 prescaler: 0,5 microseconds at 16mhz
	TIMSK1 |= (1 << OCIE1A); // enable timer compare interrupt
	sei();
}



void loop(){
	// for(int i=1200;i<1800;i++) {
	// 	for(int j=0;j<6;j++)
	// 		ppm[j] = i;
	// 	delay(10);
	// }

	uint8_t pos = 0;
	if (Serial.available())
		while (Serial.available())
			((uint8_t*)ppm)[pos++] = Serial.read();

}

ISR(TIMER1_COMPA_vect){  //leave this alone
	static boolean state = true;

	TCNT1 = 0;

	if (state) {  //start pulse
		digitalWrite(sigPin, onState);
		OCR1A = PULSE_LENGTH * 2;
		state = false;
	} else{  //end pulse and calculate when to start the next pulse
		static byte cur_chan_numb;
		static unsigned int calc_rest;

		digitalWrite(sigPin, !onState);
		state = true;

		if(cur_chan_numb >= CHANNEL_NUMBER){
			cur_chan_numb = 0;
			calc_rest = calc_rest + PULSE_LENGTH;//
			OCR1A = (FRAME_LENGTH - calc_rest) * 2;
			calc_rest = 0;
		}
		else{
			OCR1A = (ppm[cur_chan_numb] - PULSE_LENGTH) * 2;
				calc_rest = calc_rest + ppm[cur_chan_numb];
			cur_chan_numb++;
		}
	}
}