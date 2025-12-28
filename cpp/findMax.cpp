#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter the size of array\n";
    cin>>n;
    int a[n];

    for(auto &x:a){
        cin>>x;
    }
    int max=0;
    for(int i=0; i<n;i++){
        if(a[i]>a[i+1]){
            max=a[i];
        }
    }
    cout<<"the max is "<<max;

    
    return 0;
}