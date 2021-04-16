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

get('/error') do
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
    slim(:"helper/error", locals: {message: message, link_text: link_text, link: link})
end

before do
    check_logged_in()
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

    sort_times(times)

    #Vi måste ändra så att vi skickar med användarnamnen för varje tid, istället
    #för användarnas id

    #Visa dem för användaren
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
        show_error_message("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorin", route_back)
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
        show_error_message("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorier", route_back)
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
        show_error_message("Du är inte skaparen av denna kategorin. Du kan inte radera en kategori som någon annan äger", "Tillbaka till kategorier", route_back)
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
        show_error_message("Du är inte skaparen av denna tiden. Du kan inte radera en tid som tillhör någon annan", "Tillbaka till tiden", route_back)
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


end

get('/register') do
    slim(:"users/new")
end

post('/register') do
    #Hämta användarnamnet som användaren skrev in (input i formuläret)
    username_input = params[:username_input]

    #Hämta lösenordet som användaren skrev in
    password_input = params[:password_input]

    #Hämta det bekräftade lösenordet som användaren skrev in
    password_confirm_input = params[:password_confirm_input]


end


get('/logout') do
    slim(:"auth/logout")
end