# Projektplan

## 1. Projektbeskrivning (Beskriv vad sidan ska kunna göra).
Min applikation ska hålla koll på världsrekord. Lite mer specifikt ska det vara en sida där användare kan logga in och sedan skapa eller hitta redan existerande kategorier som de kan antingen se eller skicka in sina rekordtider till. Ett exempel kan vara att en användare skapar en kategori som kallas Äta äpple. Då kan folk skicka in sina rekordtider som de ätit äpple på. I varje kategori ska man också kunna se en ranklista över användarna med de bästa tiderna. Det är alltså en speedrunning-hemsida, och applikationen ska kallas för snabbspringning. Man ska också kunna dels radera och redigera sina inskickade tider.

## 2. Vyer (visa bildskisser på dina sidor).
Se skiss.png

## 3. Databas med ER-diagram (Bild på ER-diagram).
Se er_diagram.png

## 4. Arkitektur (Beskriv filer och mappar - vad gör/innehåller de?).
Mitt projekt följer MVC, det vill säga Model, View och Controller. Mitt projekt är därför uppdelat i dessa tre olika delar. controller.rb är Controller-delen och hanterar alla routes, all kommunikation med servern, sessions, och så vidare. model.rb är Model-delen och hanterar t.ex. all kommunikation med databasen, samt finns många hjälpfunktioner som inte behövs i Controller-delen. View-delen är alla slim-filer som finns i "views"-mappen. (slim är ett språk som tillåter en att skriva html tillsammans med ruby-kod). Där har jag grupperat mapparna efter olika entiteter i databasen. Jag har följt RESTful routes-principen, vilket är en standard i hur man hanterar och döper routes. Jag har grupperat slim-filerna (vyerna) efter deras entiteter som sagt, och varje grupp (submapp) innehåller alla vyer som hör till entitetens CRUD-interface. Det finns övriga grupper av vyer som inte har något med CRUD-interfacet att göra men är viktiga för hemsidan, t.ex. login-page (auth), information-page (helper) och så vidare. "public"-mappen innehåller css-filen som används för att få en mer sofistikerad layout och design på hemsidan. Med hjälp av style.css har jag lyckats öka användarvänligheten på sidan. "misc"-mappen innehåller övriga filer som har med projektet att göra. Jag använder också yardoc för dokumentation av min kod. "db"-mappen innehåller databasen som jag använder ett antal gånger i min kod.


