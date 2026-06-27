#include<iostream>
using namespace std;
const int maxN = 10000;
int dp[maxN];   // dp[i]表示以第i个元素作为最后元素的最长递增子序列的长度
int res = 1;
int main(){
    int n;
    int arr[maxN];
    cin >> n;
    for( int i=1; i<=n; i++ ){
        cin >> arr[i];
    }
    for( int i=1; i<=n; i++ ){
        dp[i] = 1;
        for( int j=1; j<=i-1; j++ ){
            if(arr[i] > arr[j]){
                dp[i] = max(dp[i], dp[j]+1);
            }
        }
        res = max(res, dp[i]);
    }
    cout << res;
    return 0;
}
