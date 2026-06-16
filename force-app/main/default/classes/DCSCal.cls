public with sharing class DCSCal {

	public DCSCalendarHelper.aMonth calMonth {get;set;}
	public Id target{get;
		set{
			target = value;
			calMonth.getCategories(target);	
		}
	}
			
	public DCSCal(){
		calMonth = new DCSCalendarHelper.aMonth();
	}

	public pagereference PrevMonth(){
		calmonth.PrevMonth();
		calMonth.getData();
		return null;
	}
	public pagereference NextMonth(){
		calmonth.NextMonth();
		calMonth.getData();
		return null;
	}
}