import Apex from "./apex";
import Notification from "./notification";

export class Utilities {
    static Apex = Apex;
    static Notification = Notification;

    static getDateISOString = (value) => {
        return value.toISOString().split('T')[0];
    };

    static getDateTimeISOString = (value) => {
        return value.toISOString();
    };

    static getDateFromString = (value) => {
        return new Date(Date.parse(value));
    };

    static getLocalDateISOString = (value) => {
        const offset = value.getTimezoneOffset()
        value = new Date(value.getTime() - (offset*60*1000))
        return value.toISOString().split('T')[0];
    };

    static getLocalDateFromISOString = (value) => {
        let result = new Date(value);
        return new Date(result.getTime() + (result.getTimezoneOffset() * 60000));
    };
}