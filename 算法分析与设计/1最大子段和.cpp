#include<iostream>
using namespace std;
int MaxSubSum(int *a,int left,int right)
{
    int sum = 0;
    if(left == right)
        sum = a[left] > 0 ? a[left] : 0;
    else
    {
        int center = (left + right)/2;
        int leftsum = MaxSubSum(a, left, center);
        int rightsum = MaxSubSum(a,center+1,right);
        int s1 = 0;
        int lefts = 0;
        for(int i =center; i>=left; i--)
        {
            lefts +=a[i];
            if(lefts > s1)
                s1 = lefts;
        }
        int s2 = 0;
        int rights = 0;
        for(int j = center +1; j<=right; j++)
        {
            rights += a[j];
            if(rights> s2)
                s2 = rights;
        }
        sum = s1+s2;
        if(sum<leftsum)
            sum = leftsum;
        if(sum<rightsum)
            sum = rightsum;
    }
    return sum;
}

int MaxSum(int n,int *a)
{
    return MaxSubSum(a,0,n);
}

int main()
{
    int a[] = {-2,11,-4,13,-5,-2};
    cout<<"最大子段和是:"<<MaxSum(5,a)<<endl;
    return 0;
}
