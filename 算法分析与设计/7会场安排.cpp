#include <bits/stdc++.h>
#include<iostream>
using namespace std;
struct huichang
{
    int start;
    int end;
    int flag=0;
}hc[100];
bool cmp(struct huichang h1,struct huichang h2)
{
  return h1.start<h2.start;
}
int main()
{
     freopen("hcap.txt","r",stdin);
     int n;
     int hc_num=0;
     cin>>n;
     for(int i=0;i<n;i++)
     {
         cin>>hc[i].start>>hc[i].end;
     }

     sort(hc,hc+n,cmp);
     int *time=new int [n];         //每个会场当前的活动结束时间
     for(int i=0;i<n;i++)
        time[i]=999;
     hc_num=1;
     time[0]=hc[0].end;
     for(int j=1;j<n;j++)         //对于每个活动循环
     {
         for(int t=0;t<n;t++)     //对于每个会场
         {
             if(hc[j].start>=time[t])   //j的结束时间大于i，则不用加会场数
             {
                  time[t]=hc[j].end;
                  hc[j].flag=1;         //标记
                  break;
             }
         }
         if(!hc[j].flag)    hc_num++;
     }
    cout<<hc_num;
}
