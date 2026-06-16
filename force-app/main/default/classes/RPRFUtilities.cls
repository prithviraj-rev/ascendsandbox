/******************************************************************************
// Project:         Resource Planning and Revenue Forecasting
// Summary:         Helper class with a number of re-usable static methods
// Test Class:      RPRFUtilitiesTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 04/29/2024 - created
*******************************************************************************/

public with sharing class RPRFUtilities 
{
    public static String formatDate(Date dt, String format) {
        if(dt == null) return null;
        return DateTime.newInstance(dt, Time.newInstance(0, 0, 0, 0)).format(format);
    }

    public static Integer dayOfWeek(Date value) {
		return Math.mod(DateTime.newInstanceGMT(value.year(), value.month(), value.day()).getTime() - 259200000, 7).intValue();
	}

    public static Boolean isWeekend(Date value) {
		Integer dayOfWeek = dayOfWeek(value);
        return dayOfWeek == 6 || dayOfWeek == 0;
	}

    public static Set<Date> getWeekends(Date fromDate, Date toDate) {
        Set<Date> result = new Set<Date>();
        if(fromDate == null || toDate == null) return result;

        for(Date day = fromDate; day <= toDate; day = day.addDays(1)) {
            if(RPRFUtilities.isWeekend(day)) result.add(day);
        }

        return result;
    }

    public static Date getMaxDate(Set<Date> values) {
        return getMaxDate(new List<Date>(values));
    }

    public static Date getMaxDate(List<Date> values) {
        if(values == null || values.isEmpty()) return null;

        values = values.clone();
        values.sort();
        return values[values.size() - 1];
    }

    public static Date getMinDate(Set<Date> values) {
        return getMinDate(new List<Date>(values));
    }

    public static Date getMinDate(List<Date> values) {
        if(values == null || values.isEmpty()) return null;

        values = values.clone();
        values.sort();
        return values[0];
    }

    public static String getExceptionMessage(Exception ex) {
        return getExceptionMessage(ex, false);
    }

    public static String getExceptionMessage(Exception ex, Boolean stackTrace) {
        String result = (stackTrace ? ex.getMessage() + '; ' + ex.getStackTraceString() : ex.getMessage());
        if(ex instanceof DmlException) {
            List<String> messages = new List<String>();
            DmlException dmlEx = (DmlException)ex;
            for(Integer i = 0; i < dmlEx.getNumDml(); i++) {
                messages.add(dmlEx.getDmlMessage(i));
            }

            result = String.join(messages, '\r\n');
            if(stackTrace) result += '\r\n' + ex.getStackTraceString();
        }

        return result;
    }

    public static Object stringToObject(String value, Schema.DisplayType fieldType)
	{
		if(fieldType == Schema.DisplayType.Boolean)
		{
			if(String.isEmpty(value)) return false;
			return Boolean.valueOf(value);
		}else if(fieldType == Schema.DisplayType.Currency ||
				fieldType == Schema.DisplayType.Double ||
				fieldType == Schema.DisplayType.Percent)
		{
			if(String.isEmpty(value)) return null;
			return Decimal.valueOf(value);
		}else if(fieldType == Schema.DisplayType.Integer)
		{
			if(String.isEmpty(value)) return null;
			return Integer.valueOf(value);
		}else if(fieldType == Schema.DisplayType.Date)
		{
			if(String.isEmpty(value)) return null;
			try{ return Date.valueOf(value); }catch(Exception ex)
			{ return Date.parse(value); }
		}else if(fieldType == Schema.DisplayType.DateTime)
		{
			if(String.isEmpty(value)) return null;
			if(value.contains('T'))
			{
				try{ return DateTime.valueOfGmt(value.replace('T', ' ').replace('Z', '')); }catch(Exception ex){}
			}else{
				try{ return DateTime.valueOf(value); }catch(Exception ex) {}
			}
			return DateTime.parse(value);
		}else if(fieldType == Schema.DisplayType.Time)
		{
			if(String.isEmpty(value)) return null;

			if(value.contains('Z')) return DateTime.valueOf('2000-01-01 ' + value.replace('Z', '')).time();
			else if(value.containsIgnoreCase(' AM') || value.containsIgnoreCase(' PM')) return DateTime.parse(Date.newInstance(2000, 1, 10).format() + ' ' + value).time();
			else {
				List<String> parts = value.split('\\.');
				String milliseconds = (parts.size() > 1 ? parts[1] : null);

				parts = parts[0].split(':');
				if(parts.size() == 1) parts.add('00');
				if(parts.size() == 2) parts.add('00');

				Time result = DateTime.valueOf('2000-01-01 ' + String.join(parts, ':')).time();
				if(!String.isEmpty(milliseconds)) result = result.addMilliseconds(Integer.valueOf(milliseconds));
				return result;
			}
		}else if(fieldType == Schema.DisplayType.Reference || fieldType == Schema.DisplayType.ID)
		{
			if(String.isEmpty(value)) return null;
			return (ID)value;
		}else if(fieldType == Schema.DisplayType.Base64)
		{
			if(String.isEmpty(value)) return null;
			return Blob.valueOf(value);
		}else if(fieldType == Schema.DisplayType.Picklist || fieldType == Schema.DisplayType.MultiPicklist || 
				fieldType == Schema.DisplayType.Email || fieldType == Schema.DisplayType.Url || 
				fieldType == Schema.DisplayType.Phone || fieldType == Schema.DisplayType.Combobox || 
				fieldType == Schema.DisplayType.Location || fieldType == Schema.DisplayType.EncryptedString || 
				fieldType == Schema.DisplayType.Address)
		{
			if(String.isEmpty(value)) return null;
			return value;
		}else return value;
	}

    /******************* CACHE METHODS *******************/

    private static Map<String, Object> cache = new Map<String, Object>();

    public static void clearCache() {
    	cache.clear();
    }
	
	public static Boolean containsInCache(String key) {
		return cache.containsKey(key);
	}
	
	public static void removeFromCache(String key) {
		cache.remove(key);
	}
	
	public  static Object extractFromCache(String key) {
		return cache.get(key);
	}
	
	public static void addToCache(String key, Object value) {
		cache.put(key, value);
	}
}