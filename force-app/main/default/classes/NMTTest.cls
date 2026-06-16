@isTest
public class NMTTest {
    public static testmethod void testException(){
        Test.startTest();
        try{
			throw new NAMOtherToolInProgressException();
        }catch(NAMOtherToolInProgressException e){}
		Test.stopTest();
    }
}