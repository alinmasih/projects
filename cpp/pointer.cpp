#include <iostream>
using namespace std;

int main(){
    int x =10;
    int *p;
    p =&x;
    cout<<x<<"\n";//10
    cout<<&x<<"\n";//add of x
    cout<<p<<"\n";// add of x
    cout<<&p<<"\n";//add of p
    cout<<*p<<"\n";//x=10

    
    return 0;
}