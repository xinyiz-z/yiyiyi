#include<stdlib.h>
#include<iostream>
using namespace std;

template<class Type>
void Prim(int n, Type c[][100])
{
    Type lowest[100];
    Type closeest[100];
    bool s[100];
    s[1] = true;
    for(int i=2;i<=n;i++){
        lowest[i]=c[1][i];
        closeest[i]=1;
        s[i] = false;
    }
    for(int i=1;i<n;i++){
        int min=100;
        int j = 1;
        for(int k=2;k<=n;k++){
            if(lowest[k]<min&&!s[k]){
                min = lowest[k];
                j = k;
            }
        }
        s[j] = true;
        cout<<j<<' '<<closeest[j]<<endl;
        for(int k=2;k<=n;k++){
            if(!s[k]&&c[j][k]<lowest[k]){
                lowest[k] = c[j][k];
                closeest[k] = j;
            }
        }
    }
}

int main()
{
    int n;
    cout<<"输入个数：";
    cin>>n;
    cout<<"边的权值：";
        int c[100][100];
    for(int i=1;i<=n;i++)
    {
        for(int j=1;j<=n;j++)
            cin>>c[i][j];
    }
    Prim(n,c);
    return 0;
}
