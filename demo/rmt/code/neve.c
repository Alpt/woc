/* Sun Jan 30 21:42:54 CET 2005
 * by AlpT
 * Un regalo per crash da un'idea di crash :***/

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sys/types.h>
#include <unistd.h>


char S[9]="*.,'+ `:;";

inline int rand_range(int _min, int _max)
{
	return (rand()%(_max - _min + 1)) + _min;
}
int surandom(char *file)
{
	FILE *fd;
	int seed;

	fd=fopen("/dev/urandom", "r");
	fread(&seed, 4,1,fd);
	fclose(fd);
	srand(seed);
	return seed;
}

int surandom2(void)
{
	srand(getpid()+time(0));
}

int main()
{
	int i, x, e, o, buh;

	/*surandom("/dev/urandom");*/
	surandom2();

	buh=rand_range(10,100);
	for(o=0; o<buh; o++) {
		x=rand_range(1,30);
		e=0;
		for(i=0; i<=80; i++) {
			if(rand_range(0, 10) < 4 && e<x) {
				printf("%c", S[rand_range(0,9)]);
				e++;
			} else
				printf(" ");
		}
		printf("\n");
	}
}
