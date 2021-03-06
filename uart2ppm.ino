#define CHANNEL_NUMBER 6
#define CHANNEL_DEFAULT_VALUE 1500
#define FRAME_LENGTH 40000
#define PULSE_LENGTH 397
#define onState 0
#define sigPin 12
#define gndPin 11
#define ledPin 13
#define FRAME_SIZE_RX (6*2+2)

uint8_t rx_buffer[FRAME_SIZE_RX];
uint8_t rx_buffer_index = 0;

void push_rx_buffer(uint8_t d) {
	rx_buffer[rx_buffer_index] = d;
	rx_buffer_index = (rx_buffer_index+1) % FRAME_SIZE_RX;
}

uint8_t get_rx_buffer(uint8_t i) {
	return (rx_buffer[(i + rx_buffer_index) % FRAME_SIZE_RX]);
}

uint8_t check_rx_buffer() {
	uint8_t crc = 0;
	if (get_rx_buffer(0) == 42 && get_rx_buffer(6*2+1) == 43) {
		// for(uint8_t i=0;i<6*2+1;i++)
		// 	crc ^= get_rx_buffer(i);
		// return (crc == get_rx_buffer(6*2+1));
		return 1;
	}
	return 0;
}


uint16_t ppm[CHANNEL_NUMBER];

void setup(){
	Serial.begin(115200);
	for(int i=0; i<CHANNEL_NUMBER; i++)
		ppm[i]= CHANNEL_DEFAULT_VALUE;

	pinMode(sigPin, OUTPUT);
	pinMode(gndPin, OUTPUT);
	digitalWrite(sigPin, !onState);
	digitalWrite(gndPin, LOW);
	pinMode(ledPin, OUTPUT);

	cli();
	TCCR1A = 0; // set entire TCCR1 register to 0
	TCCR1B = 0;

	OCR1A = 100;  // compare match register, change this
	TCCR1B |= (1 << WGM12);  // turn on CTC mode
	TCCR1B |= (1 << CS11);  // 8 prescaler: 0,5 microseconds at 16mhz
	TIMSK1 |= (1 << OCIE1A); // enable timer compare interrupt
	sei();

	ppm[0] = 1000;
	ppm[1] = 1250;
	ppm[2] = 1500;
	ppm[3] = 1750;
	ppm[4] = 2000;

}

uint8_t pos = 0;
void loop(){
	if (Serial.available()) {
		char c = Serial.read();
		push_rx_buffer(c);
		if (check_rx_buffer()) {
			digitalWrite(ledPin, HIGH);
			uint8_t *ptr = (uint8_t*)ppm;
			for (int i=0; i<6*2; i++)
				ptr[i] = get_rx_buffer(i+1);
		}
		else
			digitalWrite(ledPin, LOW);
	}
}

ISR(TIMER1_COMPA_vect){
	static boolean state = true;

	TCNT1 = 0;

	if (state) {  //start pulse
		digitalWrite(sigPin, onState);
		OCR1A = PULSE_LENGTH * 2;
		state = false;
	} else {  //end pulse and calculate when to start the next pulse
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
