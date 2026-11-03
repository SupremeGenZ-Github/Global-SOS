import {useEffect,useState} from 'react';
import catalogue from '../../shared/languages.json';
export const languages=catalogue.languages;
export function languageIntent(text:string):string|null{for(const [id,pattern]of Object.entries(catalogue.intents))if(new RegExp(pattern,'iu').test(text))return id;return null;}
export function useLanguage(){
 const [locale,setLocale]=useState(()=>{try{return localStorage.getItem('sos_language')||'en';}catch{return 'en';}});
 const language=languages.find(l=>l.code===locale)??languages[0];
 useEffect(()=>{document.documentElement.lang=language.code;document.documentElement.dir=language.direction;try{localStorage.setItem('sos_language',language.code);}catch{}},[language.code]);
 const t=(text:string)=>(language.labels as Record<string,string>)[text]??text;
 return {locale:language.code,setLocale,t};
}
