#include <stdlib.h>
#include <stdio.h>
#include <time.h>

int main(void)
{
    srand(time(NULL));
    int x = 0;
    while (x < 10) {
        
        int col = (rand() % (9 + 1 - 1) + 1);
        int col2 = (rand() % 10) + 1;
        printf("col %d\n", col);
        printf("col %d\n", col2);
        printf("\n");
        x= x+1;
    }
}