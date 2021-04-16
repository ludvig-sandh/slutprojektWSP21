require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

#1. Skapa ER + databas som kan hålla användare och tider. Fota ER-diagram, 
#   lägg i misc-mapp
#2. Skapa ett formulär för att registrerara användare.
#3. Skapa ett formulär för att logga in. Om användaren lyckas logga  
#   in: Spara information i session som håller koll på att användaren är inloggad
#4. Låt inloggad användare skapa todos i ett formulär (på en ny sida ELLER på sidan som visar todos.).
#5. Låt inloggad användare updatera och ta bort sina formulär.
#6. Lägg till felhantering (meddelande om man skriver in fel user/lösen)


#Övriga routes
get('/') do
    redirect('/home')
end

get('/home') do
    slim(:home)
end

get('/inform') do
    message = session[:message]
    link_text = session[:link_text]
    link = session[:link]
    if message == nil || link_text == nil || link == nil
        #Om det i framtiden läggs till flera error-hanterare och man missar att
        #specifiera en beskrivning av felmeddelandet så visas detta som default
        message = "Det har uppstått ett fel, vänligen kontakta Ludvig Sandh."
        link_text = "Hem"
        link = "/home"
    end
    slim(:"helper/inform", locals: {message: message, link_text: link_text, link: link})
end

#Omdirigerar användaren till en sida som visar information till användaren
def display_information(mes, link_t, link) #FLYTTA TILL CONTROLLER
    session[:message] = mes
    session[:link_text] = link_t
    session[:link] = link
    redirect('/inform')
end

#Categories
get('/categories') do
    #Koppling till databasen, och hämta alla kategorier
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    
    #Visa dem för användaren
    slim(:"categories/index", locals: {categories: categories})
end

get('/categories/new') do
    #Detta får bara inloggade användare göra
    check_logged_in()

    #Visa formuläret för den som var inloggad
    slim(:"categories/new")
end

#Här visar vi alla tider för en viss kategori
get('/categories/:id') do
    category_id = params[:id]
    
    #Hämta alla tider som finns sparade för denna kategorin
    db = connect_to_db()
    times = db.execute('SELECT * From Times WHERE category_id = ?', category_id)
    cat = db.execute('SELECT * From Categories WHERE id = ?', category_id).first
    
    #Sorterar alla tider så att ranklistan ordnas efter dem
    sort_times(times)

    #Hitta användarnamnen för alla tider i ranklistan (i sorterad ordning förstås)
    times.each do |time|
        user_id = time["user_id"]
        #Från id:t - hämta användarnamnet och spara det också som en nyckel (par + värde) i vår times-dictionary
        username = db.execute('SELECT username FROM Users WHERE id = ?', user_id).first
        time["username"] = username["username"]
    end

    #Visa ranklistan för användaren
    slim(:"categories/show", locals: {times: times, cat: cat})
end

get('/categories/:id/edit') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]

    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/categories/#{category_id}"
    session[:route_back] = route_back
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    db = connect_to_db()
    category = db.execute('SELECT * From Categories WHERE id = ?', category_id).first
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorin", route_back)
    else
        slim(:"categories/edit", locals: {category: category})
    end
end

post('/categories/:id/update') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]

    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/categories/#{category_id}"
    session[:route_back] = route_back
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    db = connect_to_db()
    owner = db.execute('SELECT user_id From Categories WHERE id = ?', category_id).first
    owner_id = owner["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorier", route_back)
    end
    
    #Användaren är authorized. Hämta datan, dvs det nya namnet på kategorin, från formuläret
    new_cat_name = params[:new_name]

    #Kontrollera att det nya kategorinamnet är tillåtet
    if kategorinamn_accepted?(new_cat_name)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        db.execute('UPDATE Categories SET name = ? WHERE id = ?', new_cat_name, category_id)

        #Skicka tillbaka användaren till kategorilistan
        redirect("/categories/#{category_id}")
    end
end

post('/categories/:id/delete') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]

    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/categories/#{category_id}"
    session[:route_back] = route_back
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    db = connect_to_db()
    owner = db.execute('SELECT user_id From Categories WHERE id = ?', category_id).first
    owner_id = owner["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som får radera den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte radera en kategori som någon annan äger", "Tillbaka till kategorier", route_back)
    else
        #Vi raderar kategorin, samt alla tider som hör till denna kategorin
        db.execute("DELETE FROM Categories WHERE id=?", category_id)
        db.execute("DELETE FROM Times WHERE category_id = ?", category_id)
    end
    
    #Skicka tillbaka användaren till kategorilistan
    redirect("/categories")
end

post('/categories') do
    #Backup-route: dvs var ska användaren skickas om den inte får authorization?
    route_back = "/categories"
    session[:route_back] = route_back

    #Detta får bara inloggade användare göra
    user_id = get_user_id()

    #Hämta data från formuläret
    kategorinamn = params[:name]

    #Kontrollera att kategorinamnet är tillåtet
    if kategorinamn_accepted?(kategorinamn)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        db = connect_to_db()
        db.execute('INSERT INTO Categories (name, user_id) VALUES (?, ?)', kategorinamn, user_id)
        redirect('/categories')
    end
end

#Times
get('/times/:category_id/new') do
    #Hämta vilket kategori-id som användaren vill lägga till en tid för
    category_id = params[:category_id]

    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/categories/#{category_id}"
    session[:route_back] = route_back

    #Detta får bara inloggade användare göra
    check_logged_in()

    #Hämta kategorinamnet för denna kategorin
    db = connect_to_db()
    category = db.execute('SELECT * From Categories WHERE id = ?', category_id).first

    #Visa formuläret för den som är inloggad
    slim(:"times/new", locals: {category: category})
end

get('/times/:category_id/:time_id') do
    #Detta får vem som helst göra

    #Hämta vilket kategori-id som tiden finns i
    category_id = params[:category_id]

    #Hämta kategorinamnet för denna kategorin
    db = connect_to_db()
    category = db.execute('SELECT * From Categories WHERE id = ?', category_id).first

    #Hämta vilket tids-id som tiden har
    time_id = params[:time_id]

    #Hämta data om denna tiden
    time = db.execute('SELECT * From Times WHERE id = ?', time_id).first

    #Visa denna tiden i mer detalj
    #Här vill vi också att vi ska se användarnamnet sen, och inte användar-id:t
    slim(:"times/show", locals: {cat: category, time: time})
end

#Entiteten "Times" har attributen user_id, category_id, date (datum då tiden skapad), time (själva tiden)
post('/times/:category_id') do
    #Hämta vilket kategori-id som användaren vill lägga till en tid för
    category_id = params[:category_id]

    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/categories/#{category_id}"
    session[:route_back] = route_back

    #Detta får bara inloggade användare göra
    user_id = get_user_id()

    #Hämta tiden som skickats in av användaren
    hours, mins, secs, fracs = get_form_time_info()
    
    #Kontrollera att tiden är tillåten
    check_time_input_accepted([hours, mins, secs, fracs], category_id)

    #Formatera tidssträngen
    time_string = time_to_string(hours, mins, secs, fracs)
    
    #Hämta datumet och klockslaget för denna tidens inskickning
    date = Time.now.strftime("%A, %B %d %Y - %k:%M:%S")

    #lägg till dbtråd som sparar tiden
    db = connect_to_db()
    db.execute('INSERT INTO Times (time, date, category_id, user_id) VALUES (?, ?, ?, ?)', time_string, date, category_id, user_id)

    redirect("/categories/#{category_id}")
end

post('/times/:category_id/:time_id/delete') do
    #Hämta tids-id som vi hanterar (från parametrar)
    time_id = params[:time_id]

    #Hämta kategori-id:t
    category_id = params[:category_id]
    
    #Backup-route: dvs var ska användaren skickas om den inte fick authorization?
    route_back = "/times/#{category_id}/#{time_id}"
    session[:route_back] = route_back

    #Hämta användar-id: (bara inloggade användare får ändra på en tid)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna tiden
    db = connect_to_db()
    owner = db.execute('SELECT user_id From Times WHERE id = ?', time_id).first
    owner_id = owner["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna tiden som får radera den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna tiden. Du kan inte radera en tid som tillhör någon annan", "Tillbaka till tiden", route_back)
    else
        #Vi raderar tiden
        db.execute("DELETE FROM Times WHERE id=?", time_id)
    end
    
    #Skicka tillbaka användaren till tidslistan
    redirect("/categories/#{category_id}")
end





#Users

get('/login') do
    slim(:"auth/login")
end

post('/login') do
    #Hämta användarnamnet som användaren skrev in (input i formuläret)
    username_input = params[:username_input]

    #Hämta lösenordet som användaren skrev in
    password_input = params[:password_input]

    #Hämta referens till databasen
    db = connect_to_db()

    #Hämta det krypterade lösenordet från användaren som har det inskrivna användarnamnet
    result = db.execute("SELECT * FROM Users WHERE username=?", username_input)

    #Om det inte fanns någon användare med detta användarnamnet, informera användaren
    if result.empty?
        display_information("Du har skrivit in fel användarnamn eller lösenord", "Prova igen", "/login")
    else
        #Det fanns en användare med det inskrivna användarnamnet
        result = result.first
        
        #Det lagrade krypterade lösenordet för användaren
        password_digest = result["pw_digest"]

        #Låt BCrypt hantera det krypterade lösenordet så att vi kan jämföra det sedan
        #Om det inskrivna lösenordet stämmer överens med BCrypts beräknade jämförelsebara värde
        if BCrypt::Password.new(password_digest) == password_input

            #Hämta användar-id hos usern
            user_id = result["id"]

            #Spara användar-id i sessions så att användaren kan fortsätta vara inloggad medan hen besöker hemsidan
            session[:user_id] = user_id

            #Spara användarnamnet i sessions också så att vi lätt kan komma åt det
            session[:username] = username_input

            #Informera användaren att hen är inloggad
            display_information("Välkommen tillbaka #{username_input}! Du är nu inloggad.", "Ta mig till startsidan", "/home")
        else
            #Lösenordet stämde inte
            display_information("Du har skrivit in fel användarnamn eller lösenord", "Prova igen", "/login")
        end
    end
    
    #metoden display_information redirectar användaren så en redirect här behövs inte
end

get('/users/new') do
    slim(:"users/new")
end

post('/users') do
    #Hämta användarnamnet som användaren skrev in (input i formuläret)
    username_input = params[:username_input]

    #Hämta lösenordet som användaren skrev in
    password_input = params[:password_input]

    #Hämta det bekräftade lösenordet som användaren skrev in
    password_confirm_input = params[:password_confirm_input]

    #Hämta referens till databasen
    db = connect_to_db()

    #Hämta användaren som har det inskrivna användarnamnet
    result = db.execute("SELECT id FROM Users WHERE username=?", username_input)

    #Om det inte fanns någon användare med detta användarnamnet redan
    if result.empty?
        if password_input == password_confirm_input
            #Låt BCrypt hasha + salta lösenordet
            password_digest = BCrypt::Password.create(password_input)
            p password_digest

            db.execute("INSERT INTO Users (username, pw_digest) VALUES (?, ?)", username_input, password_digest)
            display_information("Hej #{username_input}! Du har nu registrerat dig!", "Ta mig till startsidan", "/home")
        else
            display_information("Lösenordet stämde inte överens med det bekräftade lösenordet", "Prova igen", "/users/new")
        end
    else
        display_information("Det finns redan en användare med användarnamnet #{username_input}", "Prova igen", "/users/new")
    end

    #metoden display_information redirectar användaren så en redirect här behövs inte
end


get('/logout') do
    slim(:"auth/logout")
end