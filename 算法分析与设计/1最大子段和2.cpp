#include <iostream>
using namespace std;

int MaxSum(int n,int *a) {
	int sum = 0, b = 0;
	for (int i = 1; i <= n; i++) {
		if (b > 0) {
			b += a[i];
		} else {
			b = a[i];
		}
		if (b > sum) {
			sum = b;
		}
	}
	return sum;
}

int main()
{
    int a[] = {-2,11,-4,13,-5,-2};
    cout<<"最大子段和是:"<<MaxSum(5,a)<<endl;
    return 0;
}
//int main() {
//	int a[100], n;
//	cout << "请输入元素个数：";
//	cin >> n;
//	cout << "请输入各个元素：";
//	for (int i = 1; i <= n; i++) {
//		cin >> a[i];
//	}
//	cout << endl << "序列(";
//	for (int i = 1; i <= n; i++) {
//		if (i == n) {
//			cout << a[i] << ")";
//		} else {
//			cout << a[i] << ",";
//		}
//	}
//	cout << "的最大子段和为：" << MaxSum(a, n) << endl;
//	return 0;
//}
