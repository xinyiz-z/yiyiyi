#include<stdio.h>
int main()
{

}

double index(double a,int n)
{
    double index_;
    if(n==0)
        return 1;
    else if(n==1)
        return a;
    else if(n>1)
        if(n%2==0)
        {
            index_=index(a,n/2);
            return index_*index_;
        }
        else
        {
            index_=index(a,(n-1)/2);
            return index_*index_*a;
        }
    else
        return 0;
}
