#include<iostream>
#define MAXN 10000
using namespace std;

void Sort(float w[], int t[], int n)
{
    for (int i = 0; i < n; i++)
    {
        t[i] = i;
    }
    for (int i = 0; i < n; i++)
    {
        for (int j = i + 1; j < n; j++)
        {
            if (w[t[i]] > w[t[j]])
            {
                int temp = t[i];
                t[i] = t[j];
                t[j] = temp;
            }
        }
    }
}
void Loading(int x[], float w[], float c, int n,int &sum)
{  //x表示装载与否，w表示重量，c表示载重量, n表示集装箱个数
    n = sizeof(w) / sizeof(w[0]);
    int *t = new int[n + 1]; // t表示最优装载中，集装箱 i 的序号
    Sort(w, t, n);           //按w 排序（从小到大）, 希望优先装进去的集装箱
     for(int i=1;i<=n;i++)  cout<<t[i]<<" ";
    for (int i = 1; i <= n; i++)
        x[i] = 0; //一个集装箱都没有被装入
    for (int i = 1; i <= n && w[t[i]] <= c; i++)
    {
        //每步选择中，总是选择待选集装箱重量最小的一个装入，使得剩余空间最大化
        x[t[i]] = 1;
        c -= w[t[i]];
        sum++;
    }
}

int main(){
    int n;
    float c=10;
    int sum=0;
    float w[MAXN];
    int x[100];
    cout<<"请输入最高载重量和需载的古董数目："<<endl;
    cin>>c>>n;
    cout<<"请分别输入这些古董的重量:"<<endl;
    for(int i=1;i<=n;++i)
        cin>>w[i];
    Loading(x,w,c,n,sum);
    cout<<"最多可以装"<<sum<<"个"<<endl;
    for(int i=1;i<=sum;++i)
        cout<<w[i]<<" ";
    return 0;
}
