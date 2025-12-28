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
    int num;
    cout<<"enter the element to search ";
    cin>>num;
    
    // for(int i =0; i<n;i++){
    //     if(num==a[i]){
    //         cout<<"the num is "<<a[i]<<"at location "<<i+1<<"\n";
    //     }
    // }

    for(auto x:a){
        if(num==x){
            cout<<"the num is "<<x<<"at location "<<&x<<"\n";
        }
    }


    
    return 0;
}