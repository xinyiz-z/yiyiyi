#include <iostream>
#include <stdio.h>
using namespace std;

void BubbleSort1(long *arr,long sz){
    long i = 0;
    long j = 0;
    for(i=0;i<sz-1;i++){
        for(j=0;j<sz-i-1;j++){
            if(arr[j]>arr[j+1]){
                long tmp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = tmp;
            }
        }
    }
}

double MinTime(long n,long t[]){
    BubbleSort1(t,n);
    double sum = 0;
    for(long i = 0; i < n; i++){
        sum = sum + t[i] * (n - i);
    }
    return sum / n;
}

int main()
{
    long n;
    scanf("%ld",&n);
    long t[n] = {0};
    for(long i = 0; i < n; i++)
        scanf("%ld",&t[i]);
    printf("\n%.2lf",MinTime(n,t));
    return 0;
}
