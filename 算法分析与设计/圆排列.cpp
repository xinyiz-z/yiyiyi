#include"stdlib.h"
#include<iostream>
using namespace std;
#include"iomanip"
#include <math.h>

class Circle//构造了一个类，里面包含了相关需要元素
{
    friend float CirclePerm(int, float *);//利用友元访问private元素
private:
    float Center(int t);//计算当前所选择圆的圆心横坐标
    void Compute(void);//计算当前圆排列长度
    void Backtrack(int t);//利用回溯计算左右边界以及矩阵长度
    float min,//当前最优值
             *x,//当前圆排列圆心横坐标
             *r;//当前圆排列
    int n;//待排列圆个数
};

float Circle::Center(int t) //计算当前所选择圆的圆心横坐标
{
    float temp = 0;
    for(int j = 1; j < t; j++)//使用循环，因为不一定该圆与其前一个圆相切，其可能与任意一个圆相切
    {
        float valuex = x[j] + 2.0*sqrt(r[t]*r[j]);//相切时圆心坐标
        if(valuex > temp)
            temp = valuex;//记录下坐标最大值
        }
    return temp;
}

void Circle::Compute(void){
    float low = 0, high = 0;
    for (int i = 1; i <= n; i++){//使用循环，因为左右边界不一定就是由第一个最后一个决定的
        if(x[i]-r[i] < low)
            low = x[i] - r[i];//下界由圆心减去半径得出
        if(x[i]+r[i] > high)
            high = x[i]+r[i];//上界由圆心加上半径得出
    }
    if(high-low < min)
        min = high - low;//更新矩形宽度最小
}

void Circle::Backtrack(int t){
    if(t > n)
        Compute();//当排列完成时，计算当前矩形宽度
    else{
        for(int j=t; j<=n; j++){//展开分支
            swap(r[t], r[j]);//通过交换位置的方式实现排列
            float centerx = Center(t);
            if(centerx+r[t]+r[1]<min){//下界约束，但只能做出一个较为粗略的估计，所以还要用compute进行检验，虽然这里做出的估计较为粗略但是节省了时间也剪掉了部分分支
                x[t] = centerx;
                Backtrack(t+1);
            }
            swap(r[t], r[j]);//交换回来保证排列完全不重复
        }
    }
}

float CirclePerm(int n, float *a){
    Circle X;
    X.n = n;
    X.r = a;
    X.min = 100000;
    float *x = new float[n+1];
    X.x = x;
    X.Backtrack(1);
    delete[] x;
    return X.min;
}

int main()
{
    int n=3;
    float a[4]={0,1,1,2};
    cout<<"最小长度为："<<CirclePerm(n,a);
    return 0;
}
