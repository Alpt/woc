/*
 * Random stuff ;)
 *
 * AlpT (@freaknet.org)
 */
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sys/types.h>
#include <unistd.h>

/*\
 *
 *
 * 	* * *  Random functions  * * *
 *
 *
\*/

void xsrand(void);

#define URANDOM_DEVICE			"/dev/urandom"

unsigned short int _rnd_rng_state[3];
FILE *_rnd_urandom_fd=0;

/*
 * init_rand
 *
 * Initialize this code
 */
void init_rand(void)
{
	if(!_rnd_urandom_fd)
		_rnd_urandom_fd=fopen(URANDOM_DEVICE, "r");
	xsrand();
}

void close_rand(void)
{
	if(_rnd_urandom_fd)
		fclose(_rnd_urandom_fd);
}

/*
 * get_time_xorred
 *
 * It returns a real random seed.
 *
 * The idea is simple: the microseconds of the current time returned by
 * gettimeofday() mess up everything.
 * It is impossible to know what `tv_usec' will be in a given instant.
 * The returned value is the `tv_usec' xorred with `tv_sec'.
 *
 * You should not use get_time_xorred() to get a random number, because the
 * returned values are not uniformly distributed.
 * The correct use of this function is to set the random seed using srand(),
 * seed48(), _only if_ /dev/urandom is not present in the OS.
 */
int get_time_xorred(void)
{
        struct timeval t;
        gettimeofday(&t, 0);

        return t.tv_usec ^ t.tv_sec;
}
void _xsrand(void)
{
	unsigned int seed;

	if(_rnd_urandom_fd)
		fread(&seed, sizeof(unsigned int), 1, _rnd_urandom_fd);
	else
		seed=getpid() ^ clock() ^ get_time_xorred();

	srand(seed); 
}

void _xsrand48(void)
{
	if(_rnd_urandom_fd)
		fread(_rnd_rng_state, sizeof(_rnd_rng_state), 1, _rnd_urandom_fd);
	else {
		long sc=0;

#ifdef _SC_AVPHYS_PAGES
		sc=sysconf(_SC_AVPHYS_PAGES);
#endif

		_rnd_rng_state[0]=clock() ^ getpid() ^ get_time_xorred();
		_rnd_rng_state[1]=clock() ^ sc ^ get_time_xorred();
		_rnd_rng_state[2]=get_time_xorred();
	}

	seed48(_rnd_rng_state);
}

/* 
 * xsrand
 *
 * It sets the random seed with a pseudo random number 
 */
void xsrand(void)
{
//XXX: activate when necessary	_xsrand();
	_xsrand48();
}

inline long int xrand_fast(void)
{
	return nrand48(_rnd_rng_state);
}

long int xrand(void)
{
	long int r=0;

	if(_rnd_urandom_fd)
		fread(&r, sizeof(long int), 1, _rnd_urandom_fd);
	else
		r=xrand_fast();

	return abs(r);
}

/* 
 * rand_range: It returns a random number x which is _min <= x <= _max
 */ 
inline int rand_range(int _min, int _max)
{
	return ((int)xrand()%(_max - _min + 1)) + _min;
}


int main(int argc, char **argv)
{
	unsigned int min, max;

	if(argc<2) {
		printf("Usage:\n"
			"       `rand_range [min] max' returns a random\n"
			"        number between `min' (or 0) and `max'\n"
			"        (inclusive)\n"
			"\n"
			"       `rand_range rand' returns a random "
			"        number between 0 and 2^32-1\n");
		exit(1);
	} else if(argc==2) {
		min=0;
		if(!strcasecmp(argv[1], "rand"))
			max=1<<32-1;
		else
			max=atoi(argv[1]);
	} else {
		min=atoi(argv[1]);
		max=atoi(argv[2]);
	}

	init_rand();
	printf("%ld\n", (unsigned int)rand_range(min, max));
	close_rand();
	exit(0);
}
