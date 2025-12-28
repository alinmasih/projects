#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter the size of array"<<endl;
    cin>>n;
    int a[n];
    for(int i=0; i<n; i++){
        cin>>a[i];
    }

    int sum =0;

    for(int i=0; i<n; i++){
        sum+=a[i];
    }

    cout<<"the sum is "<<sum;


    return 0;
}