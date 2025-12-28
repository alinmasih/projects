#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter the size of array\n";
    cin>>n;
    int a[n];

    for(auto x:a){
        cin>>x;
    }
    cout<<"the array is"
    for(auto x:a){
        
        cout<<x;
    }

    
    return 0;
}