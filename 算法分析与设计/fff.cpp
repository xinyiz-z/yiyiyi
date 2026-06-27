#include<iostream>
#include<algorithm>
#define MAXN 10000
using namespace std;
int main(){
    int c,n;    //c:船的最高载重量 n:古董数量
    int sum=0,weight=0; //sum:装入的古董数量 weight:装入的古董重量
    int w[MAXN];    //单个古董对应的重量
    cout<<"请输入最高载重量和需载的古董数目："<<endl;
    cin>>c>>n;
    cout<<"请分别输入这些古董的重量:"<<endl;
    for(int i=1;i<=n;++i)
        cin>>w[i];
    sort(w+1,w+1+n);
    for(int i = 1 ; i<=n ; i++){
        weight += w[i]; //先将重量加进去
        if(weight >= c){
            if(weight == c)   //恰好装满时
                sum = i;
            else
                sum = i-1;  //超重了，需要减去一个
            break;
        }
    }
    cout<<"最多可以装"<<sum<<"个"<<endl;
    for(int i=1;i<=sum;++i)
        cout<<w[i]<<" ";
    return 0;
}
