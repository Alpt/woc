/*
* Wed Mar 22 04:08:39 CET 2006
* gcc -lm wave.c
* AlpT
*/

#include <math.h>
#include <unistd.h>

#define PI 3.1415926532

int main(int argc, char **argv)
{
	float x, y, s, count;
	int e, w, wo;
	char c, cn;

	c = argc > 1 ? argv[1][0] : '>';
	cn = argc > 2 ? argv[2][0] : '<';
	w = argc > 3 ? atoi(argv[3]) : 4000;
	wo=w;

	count=0;
loop:
	for(x=0; x<2*PI; x+=0.03) {
		y=sin(x)*40;

		s=y-1+40;
		for(e=0; e<s; e++)
			printf(" ");
		if(y<0)
			printf("%c", cn);
		else
			printf("%c", c);
		
		printf("\n");
		usleep(w);
	}
	
	count+=1;
	w+=sin(count)*(wo>>2);
	if(count >= 2*PI)
		count=0;
			
	goto loop;
}
