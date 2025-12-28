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
    int temp=0;
    for(int i =0; i<n; i++){
        if(a[i]>a[i+1]){
            temp=a[i];
            a[i]=a[i+1];
            a[i+1]=temp;
        }
    }
    for(int i =0; i<n; i++){
        cout<<" "<<a[i];
    }
    // int num;
    // cout<<"enter the number to find\n";
    // cin>>num;
    // int mid,l=0,h=n-1;

    // while(l<=h){
    //    mid=(l+h)/2;
    //     if(num==a[mid]){
    //         cout<<"the index is"<<mid-1;
    //     }
    //     else if(num>a[mid]){
    //         l=mid+1;
    //     }
    //     else {
    //         h=mid-1;
    //     } 
    // }
    
    

    



    
    return 0;
}