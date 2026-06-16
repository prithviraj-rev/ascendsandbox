global class DCSCalendarHelper {
	
	public class fieldMeta{
		public string name{get;set;}
		public string dtype{get;set;}
		public string label{get;set;}
		public string obj{get;set;}
		public string style{get;set;}
		
		
		public fieldMeta(Schema.DescribeSObjectResult objMeta, string relationship, string style){
			this.label = objMeta.getLabel();
			this.name = relationship;
			this.obj = string.valueOf(objMeta.getSObjectType());
			this.style = style;
		}
		public fieldMeta(string sObjectName, string style){
			this.name = sObjectName;
			this.obj = sObjectName.substringBefore('.');
			this.style = style;
		}
		public fieldMeta(Schema.DescribeFieldResult meta, string sObjectName){
			this.name = meta.name;
			this.label = meta.label;
			this.obj=sObjectName;
			this.dType=string.valueOf(meta.getType());
		}
		
	}
	public class aMonth{
		public Id targetId{get;set;}
		public string sType{get;set;}
		public string name{get;set;}
		public integer month{get;set;}
		public string year{get;set;}
		public date startDate{get;set;}
		public date beginDate{get;set;}
		public date endDate{get;set;}
		public string sBegin{get;set;}
		public string sEnd{get;set;}
		public list<string> days{get;set;}
		public list<list<aDay>> cal{get;set;}
		public map<date, aDay> calMap{get;set;}
		public integer populateCategories {get;set;}

		public Map<String, list<DCSCalendarHelper.fieldMeta>> DateFieldMeta {get;set;}
		public Map<String, list<DCSCalendarHelper.fieldMeta>> PopulatedDateFieldMeta {get;set;}
		public Map<String, String> ChildFields {get;set;}
		public Map<String, String> NameFields {get;set;}
		
		public list<DCSCalendarHelper.fieldMeta> objects{get;set;}
		public Map<String, DCSCalendarHelper.fieldMeta> objectMap {get;set;}
		public list<DCSCalendarHelper.fieldMeta> nobjects{get;set;}
		public Map<String, DCSCalendarHelper.fieldMeta> nobjectMap {get;set;}
		
		public Map<String, string> sQueries {get;set;}


		public aMonth()	{
			init(null);
		} 
		public aMonth(date initDate)	{
			init(initDate);
		}
		public void nextMonth(){
			date nm = this.startDate.addMonths(1);
			init(nm);
		}
		public void prevMonth(){
			date pm = this.startDate.addMonths(-1);
			init(pm);
		}

		
		public void init(date initDate){
			this.startDate = (initDate!=null)?initDate.toStartOfMonth():date.today().toStartOfMonth();
			this.beginDate = this.startDate.toStartOfWeek();
			this.endDate = this.startDate.addDays(date.daysInMonth(startDate.year(), startDate.month())-1);
			this.sBegin = string.valueOf(this.beginDate);
			this.sEnd = string.valueOf(this.endDate);
			this.year = string.valueOf(startDate.year());
			this.month = startDate.month();
			DateTime d = datetime.newInstance(startDate, time.newInstance(0,0,0,0));
			this.name= d.format('MMMMM');
			this.populateCategories=0;
			this.refresh();
		}
			
		public string title {get{return name + ' ' + year;}}
		
		public void refresh(){
			date dToday = date.today();
			date currentDate = this.beginDate;
			this.cal = new list<list<aDay>>();
			this.days = new list<string>();
			this.calMap = new map<date, aDay>();
			while (currentDate<this.endDate){
				list<aDay> thisWeek = new list<aDay>();
				this.cal.add(thisWeek);
				for (integer i=0;i<7;i++){
					string status = 'inside';
					if (currentDate.month()!=this.month){
						status='outside';
					}
					if (currentDate==dToday){
						status='today';
					}
					aDay thisDay = new aDay(currentDate,status);
					thisWeek.add(thisDay);
					calMap.put(currentDate, thisDay);
					if (this.cal.size()==1){
						DateTime d = datetime.newInstance(currentDate, time.newInstance(0,0,0,0));
						this.days.add(d.format('E'));
					}
					currentDate = currentDate.addDays(1);
				}
			}
		}
		
		public void populate(list<sObject> items, string dateField, string nameField){
			this.populateCategories += 1;
			for (sObject o:items){
				date d = (date)o.get(dateField);
				string n = string.valueOf(o.get(nameField));
				this.calMap.get(d).items.add(new dayContent(n,o.Id, populateCategories));
			}
		}
		public void populate(list<sObject> items, list<fieldMeta> dates, string nameField){
			this.populateCategories += 1;
			for (sObject o:items){
				for (fieldMeta f:dates){
					if (f.dType=='DATE'){
						date d = (date)o.get(f.name);
						if (d!=null){
							string n = f.label + ': ' + ((o.get(nameField)!=null)?string.valueOf(o.get(nameField)):'');
							if (this.calMap.containsKey(d)){
								this.calMap.get(d).items.add(new dayContent(n,o.Id, populateCategories));
								f.style='s'+string.valueOf(populateCategories);
								system.debug(f);
								if (nobjectMap.containsKey(f.obj)){
									nobjectMap.get(f.obj).style=f.style;
								}
								if (!PopulatedDateFieldMeta.containsKey(f.obj)){
									PopulatedDateFieldMeta.put (f.obj,new list<DCSCalendarHelper.fieldMeta>());
								}
								PopulatedDateFieldMeta.get(f.obj).add(f);
							}
						}
					}
				}
			}
		}

	
	public void getCategories(Id target){
		if (DateFieldMeta==null){
			objects=new list<fieldMeta>();
			objectMap = new map<string,fieldMeta>(); 
			nobjects=new list<fieldMeta>();
			nobjectMap = new map<string,fieldMeta>(); 
		
			string sprefix =String.valueOf(target).left(3);
			string sType = null;
			Schema.DescribeSObjectResult R;
			
			Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
			Set<String> keyPrefixSet = gd.keySet();
			for(String sObj : keyPrefixSet){
				R =  gd.get(sObj).getDescribe();
				system.debug('describe iteration');
				if (sprefix == R.getKeyPrefix()){
					sType = R.getName();
					fieldMeta mainObject = new fieldMeta(R , sType,'s0');
					nobjects.add(mainObject);
					nobjectMap.put(mainObject.obj, mainObject);
					
					//system.debug('found type');
					//system.debug(R);
					break;
				}
			}
			
			DateFieldMeta = new Map<String, list<DCSCalendarHelper.fieldMeta>>();
			PopulatedDateFieldMeta = new Map<String, list<DCSCalendarHelper.fieldMeta>>();
			ChildFields = new Map<String, String>();
			NameFields = new Map<String, String>();
			sQueries = new Map<String, string>();
	
			DateFieldMeta.put(sType, new list<DCSCalendarHelper.fieldMeta>());
			
			list<DCSCalendarHelper.fieldMeta> mainDateMeta = DateFieldMeta.get(sType);
			list<string> qFields = new list<string>();
			list<string> qBefore = new list<string>();
			list<string> qAfter = new list<string>();
			for (Schema.SObjectField f: R.fields.getMap().values()){
				Schema.DescribeFieldResult  xf = f.getDescribe(); 
				if (xf.getType()==Schema.Displaytype.DATE){
					mainDateMeta.add(new DCSCalendarHelper.fieldMeta(xf, sType));
					qFields.add(xf.name);
					qBefore.add(xf.name + '>= this.sBegin'  );
					qAfter.add(xf.name + '<= this.sEnd' );
				}
				if (xf.nameField==true){
					NameFields.put(sType, xf.name);
				}
			}
			if (qFields.size()>0){
				sQueries.put(sType, 'select id, ' +(NameFields.get(sType)!=null? (NameFields.get(sType) + ', '):'') + String.join(qFields, ',') + ' from ' + sType + ' where id=\'' + target + '\' and (' + String.join(qBefore, ' OR ') + ') and ('+ String.join(qAfter, ' OR ') +')');
			}
			
			for (Schema.ChildRelationship cf: R.getChildRelationships()){
				string cName = string.valueOf(cf.childSObject);
				string cField = string.valueOf(cf.field);
				Schema.SObjectType obj = gd.get(cName);
				R = obj.getDescribe();
				
				
				if (R.isQueryable() && R.isAccessible()){
					list<DCSCalendarHelper.fieldMeta> objDateMeta = new list<DCSCalendarHelper.fieldMeta>();
					qFields = new list<string>();
					qBefore = new list<string>();
					qAfter = new list<string>();
					
					Schema.DescribeFieldResult childField;
					Schema.DescribeFieldResult nameField;
					if (R.fields.getMap().containsKey('Name')){
						for (Schema.SObjectField f: R.fields.getMap().values()){
							Schema.DescribeFieldResult  xf = f.getDescribe(); 
							if (xf.getType()==Schema.Displaytype.DATE){
								system.debug(cf);
								objDateMeta.add(new DCSCalendarHelper.fieldMeta(xf, cName));
								qFields.add(xf.name);
								qBefore.add(xf.name + '>= this.sBegin'  );
								qAfter.add(xf.name + '<= this.sEnd' );
							}
							if (nameField==null && xf.nameField==true){
								nameField = xf;
								NameFields.put(cName + '.' + cField, xf.name);
							}
							if (childField==null && xf.name==cField) {
								childField = xf;
								ChildFields.put(cName + '.' + cField, cField);
							}
						}
						
						if (objDateMeta.size()>0){
							objDateMeta.add(new DCSCalendarHelper.fieldMeta(childField, cName) );
							DateFieldMeta.put(cName + '.' + cField, objDateMeta);
							sQueries.put(cName + '.' + cField, 'select id, ' +(NameFields.get(cName + '.' + cField) != null ? (NameFields.get(cName + '.' + cField)+ ', '):'') + String.join(qFields, ',') + ' from ' + cName + ' where ' + cField + '=\'' + target + '\' and (' + String.join(qBefore, ' OR ') + ') and ('+ String.join(qAfter, ' OR ') +')');
							
							fieldMeta relatedObject = new fieldMeta(R, cName + '.' + cField ,'s0');
							nobjects.add(relatedObject);
							nobjectMap.put(cName, relatedObject);
						}
					}
				}
			}
			getData();
		}
	}
	public void getData(){
		for (string sQ: sQueries.keyset()){
			string soql = sQueries.get(sQ).replace ('this.sBegin',  this.sBegin ).replace ('this.sEnd',  this.sEnd );
			list<sObject> lObj = Database.query(soql);
			
			fieldMeta tobj = new fieldMeta(sq ,'s0');
			objects.add(tobj);
			objectMap.put(tobj.obj, tobj);
			if (lObj.size()>0){
				populate(lObj, DateFieldMeta.get(sq), NameFields.get(sq));
			}
		}
		system.debug('oldobjectmeta');
		system.debug(objectMap);
		system.debug('newobjectmeta');
		system.debug(nobjectMap);
		
		
	}		
		
		
		
	}
	public class aDay {
		public string name{get;set;}
		public date dDate{get;set;}
		public string status{get;set;}
		public list<dayContent> items{get;set;}

		public aDay(date newDate, string status){
			this.name=string.valueOf(newDate.day());
			this.dDate = newDate;
			this.status = status;
			this.items = new list<dayContent>();
		}
	}
	public class dayContent {
		public string name{get;set;}
		public Id Id{get;set;}
		public string populateCategory{get;set;}
		public dayContent(string name, Id Id, integer populateCategoryNo){
			this.name = name;
			this.Id = Id;
			this.populateCategory = 's' + string.valueOf(populateCategoryNo);
		}
	}
	
	
	public static string CalendarJSON(date initDate){
		aMonth thisMonth = new aMonth(initDate);
		
		return JSON.serializePretty(thisMonth);
	}
}