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

#Felhantera lösenord, max 8 tecken!
#Validera user-input?

#Övriga routes
get('/') do
    redirect('/home')
end

get('/home') do
    slim(:"helper/home")
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
def display_information(mes, link_t, link)
    session[:message] = mes
    session[:link_text] = link_t
    session[:link] = link
    redirect('/inform')
end

#Categories
get('/categories') do
    #Hämta alla kategorier som finns
    categories = get_all_categories()
    
    #Visa dem för användaren
    slim(:"categories/index", locals: {categories: categories})
end

get('/categories/new') do
    #Detta får bara inloggade användare göra
    confirm_logged_in()

    #Visa formuläret för den som var inloggad
    slim(:"categories/new")
end

#Här visar vi alla tider för en viss kategori
get('/categories/:id') do
    category_id = params[:id]
    
    #Hämta alla tider som finns sparade för denna kategorin
    times = get_all_times_from_category(category_id)
    
    #Hämta information om kategorin
    cat = get_category(category_id)

    #Hämta användarnamnet bakom kategorin
    creator = get_username_with_id(cat["user_id"])["username"]
    
    #Sorterar alla tider så att ranklistan ordnas efter dem
    sort_times(times)

    #Hitta användarnamnen för alla tider i ranklistan (i sorterad ordning förstås)
    times.each do |time|
        user_id = time["user_id"]
        
        #Från id:t - hämta användarnamnet och spara det också som en nyckel (par + värde) i vår times-dictionary
        username = get_username_with_id(user_id)

        time["username"] = username["username"]
    end

    #Se om personen är inloggad
    user_id = session[:user_id]
    does_like = false
    if user_id != nil
        #Se om den här användaren gillar denna kategorin eller inte
        like = get_rel(user_id, category_id)
        if like != nil
            does_like = true
        end
    end

    #Hämta alla användare som gillar den här kategorin med en inner join
    users_liking = get_all_users_liking_category(category_id)

    #Visa ranklistan för användaren
    slim(:"categories/show", locals: {times: times, cat: cat, creator: creator, does_like: does_like, users_liking: users_liking, user_id: user_id})
end

get('/categories/:id/edit') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]

    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorin", "/categories/#{category_id}")
    else
        slim(:"categories/edit", locals: {category: category})
    end
end

post('/categories/:id/update') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorier", "/categories/#{category_id}")
    end
    
    #Användaren är authorized. Hämta datan, dvs det nya namnet på kategorin, från formuläret
    new_cat_name = params[:new_name]

    #Kontrollera att det nya kategorinamnet är tillåtet
    if kategorinamn_accepted?(new_cat_name)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        update_category_name(new_cat_name, category_id)

        #Skicka tillbaka användaren till kategorilistan
        redirect("/categories/#{category_id}")
    end
end

post('/categories/:id/delete') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som får radera den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna kategorin. Du kan inte radera en kategori som någon annan äger", "Tillbaka till kategorier", "/categories/#{category_id}")
    else
        #Vi raderar kategorin, samt alla tider som hör till denna kategorin
        delete_category(category_id)
    end
    
    #Skicka tillbaka användaren till kategorilistan
    redirect("/categories")
end

post('/categories') do
    #Detta får bara inloggade användare göra
    user_id = get_user_id()

    #Hämta data från formuläret
    kategorinamn = params[:name]

    #Kontrollera att kategorinamnet är tillåtet
    if kategorinamn_accepted?(kategorinamn)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        insert_category(kategorinamn, user_id)
        redirect('/categories')
    end
end

#Times
get('/times/:category_id/new') do
    #Hämta vilket kategori-id som användaren vill lägga till en tid för
    category_id = params[:category_id]

    #Detta får bara inloggade användare göra
    confirm_logged_in()

    #Hämta kategorinamnet för denna kategorin
    category = get_category(category_id)

    #Visa formuläret för den som är inloggad
    slim(:"times/new", locals: {category: category})
end

get('/times/:category_id/:time_id') do
    #Detta får vem som helst göra

    #Hämta vilket kategori-id som tiden finns i
    category_id = params[:category_id]

    #Hämta kategorinamnet för denna kategorin
    category = get_category(category_id)

    #Hämta vilket tids-id som tiden har
    time_id = params[:time_id]

    #Hämta data om denna tiden
    time = get_time(time_id)

    #Från id:t - hämta användarnamnet och skicka med det också i locals
    username = get_username_with_id(time["user_id"])

    #Visa denna tiden i mer detalj
    #Här vill vi också att vi ska se användarnamnet sen, och inte användar-id:t
    slim(:"times/show", locals: {cat: category, time: time, username: username})
end

#Entiteten "Times" har attributen user_id, category_id, date (datum då tiden skapad), time (själva tiden)
post('/times/:category_id') do
    #Hämta vilket kategori-id som användaren vill lägga till en tid för
    category_id = params[:category_id]

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
    insert_time(time_string, date, category_id, user_id)

    redirect("/categories/#{category_id}")
end

post('/times/:category_id/:time_id/delete') do
    #Hämta tids-id som vi hanterar (från parametrar)
    time_id = params[:time_id]

    #Hämta kategori-id:t
    category_id = params[:category_id]

    #Hämta användar-id: (bara inloggade användare får ändra på en tid)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna tiden
    owner_id = get_time_user_id(time_id)["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna tiden som får radera den
    if user_id != owner_id
        display_information("Du är inte skaparen av denna tiden. Du kan inte radera en tid som tillhör någon annan", "Tillbaka till tiden", "/times/#{category_id}/#{time_id}")
    else
        #Vi raderar tiden
        delete_time(time_id)
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

    #Hämta det krypterade lösenordet från användaren som har det inskrivna användarnamnet
    user = get_user_with_username(username_input)

    #Om det inte fanns någon användare med detta användarnamnet, informera användaren
    if user == nil
        display_information("Du har skrivit in fel användarnamn eller lösenord", "Prova igen", "/login")
    else
        
        #Det lagrade krypterade lösenordet för användaren
        password_digest = user["pw_digest"]

        #Låt BCrypt hantera det krypterade lösenordet så att vi kan jämföra det sedan
        #Om det inskrivna lösenordet stämmer överens med BCrypts beräknade jämförelsebara värde
        if BCrypt::Password.new(password_digest) == password_input

            #Hämta användar-id hos usern
            user_id = user["id"]

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

get('/logout') do
    session[:user_id] = nil
    session[:username] = nil
    slim(:"auth/logout")
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

    #Hämta användaren som har det inskrivna användarnamnet
    user = get_user_with_username(username_input)

    #Om det inte fanns någon användare med detta användarnamnet redan
    if user == nil
        if password_input == password_confirm_input
            #Låt BCrypt hasha + salta lösenordet
            password_digest = BCrypt::Password.create(password_input)

            insert_user(username_input, password_digest)
            
            #Hitta användarens id från databasen och spara det i session
            user_id = get_user_id_with_username(username_input)["id"]
            session[:user_id] = user_id
            session[:username] = username_input

            display_information("Hej #{username_input}! Du har nu registrerat dig!", "Ta mig till startsidan", "/home")
        else
            display_information("Lösenordet stämde inte överens med det bekräftade lösenordet", "Prova igen", "/users/new")
        end
    else
        display_information("Det finns redan en användare med användarnamnet #{username_input}", "Prova igen", "/users/new")
    end

    #metoden display_information redirectar användaren så en redirect här behövs inte
end

get('/users/:id/show') do
    #Hämta användar-id:t som vi vill kolla profilen för
    profile_user_id = params[:id]

    #Hämta information om profilen
    user = get_user(profile_user_id)

    #Hämta alla kategorier som användaren skapat
    created_cats = get_all_categories_by_user_id(profile_user_id)

    #Hämta alla tider som användaren skickat in
    submitted_times = get_all_times_by_user_id(profile_user_id)

    #Dessa sparar än så länge inte tidens kategoris namn, så vi kan
    #fixa det genom att loopa igenom varje tid och hämta det från db
    submitted_times.each do |time|
        cat_name = get_category_name(time["category_id"])
        time["category_name"] = cat_name["name"]
    end

    #Hämta alla kategorier som den här användaren gillar med en inner join
    categories_liking = get_all_categories_liked_by_user(user["id"])

    slim(:"users/show", locals: {user: user, created_cats: created_cats, submitted_times: submitted_times, categories_liking: categories_liking})
end

get('/users/:id/edit') do
    #Hämta användar-id:t som vi vill kolla profilen för
    profile_user_id = params[:id]

    #Hämta information om profilen
    user = get_user(profile_user_id)

    slim(:"users/edit", locals: {user: user})
end

post('/users/:id/update') do
    #Hämta användar-id:t som vi vill ändra profilen för
    profile_user_id = params[:id].to_i

    #Hämta användar-id:t
    user_id = session[:user_id]

    #Om dessa inte stämmer överens har inte användaren authorization för att ändra lösenord
    if profile_user_id != user_id || user_id == nil
        display_information("Du har inte behörighet att ändra lösenordet hos den här användaren", "Tillbaka", "/users/#{profile_user_id}/show")
    else
        #Hämta de inskrivna lösenorden
        current_password_input = params[:current_password]
        new_password_input = params[:new_password]
        confirm_new_password_input = params[:confirm_new_password]

        #Hämta referens till databasen
        db = connect_to_db()

        #Hämta det krypterade lösenordet från användaren
        user = get_user(user_id)

        #Det lagrade krypterade lösenordet för användaren
        password_digest = user["pw_digest"]

        #Låt BCrypt hantera det krypterade lösenordet så att vi kan jämföra det sedan
        #Om det inskrivna lösenordet stämmer överens med BCrypts beräknade jämförelsebara värde
        if BCrypt::Password.new(password_digest) == current_password_input

            if new_password_input == confirm_new_password_input

                #Låt BCrypt hasha + salta det nya lösenordet
                password_digest = BCrypt::Password.create(new_password_input)
                
                #Uppdatera det nya lösenordet i databasen
                update_password(password_digest, session[:user_id])

                #Informera användaren att hen har bytt lösenord
                display_information("Du har nu ändrat lösenordet.", "Tillbaka", "/users/#{user_id}/show")
            else
                #Informera om att de nya lösenorden inte stämde överens
                display_information("Dina nya lösenord stämde inte överens.", "Tillbaka", "/users/#{user_id}/show")
            end

        else
            #Lösenordet stämde inte
            display_information("Du har skrivit in fel lösenord", "Prova igen", "/users/#{user_id}/show")
        end
    end
end

post('/likes/:user_id/:category_id') do
    #Om användaren inte är inloggad än
    if session[:user_id] == nil
        display_information("Du måste vara inloggad för att göra detta.", "Logga in", "/login")
    end

    #Hämta parameterdata från formuläret
    user_id = params[:user_id]
    category_id = params[:category_id]

    #Se om det finns sparad data om den här gillningen
    like = get_rel(user_id, category_id)
    
    #Om användaren redan gillar den här kategorin, och vill "ogilla" den
    if like != nil
        #"ogilla" kategorin, alltså radera den här relationen
        delete_rel(user_id, category_id)
    else
        #"gilla" kategorin, lägg till relationen mellan user och kategori
        insert_rel(user_id, category_id)
    end
    redirect("/categories/#{category_id}")
end


#Hjälpfunktioner

#Hämta användar-id:t hos den inloggade användaren (från sessions)
def get_user_id()
    return session[:user_id]
end

#Se till att användaren är inloggad, annars visas meddelande
def confirm_logged_in()
    if session[:user_id] == nil
        display_information("Du är inte inloggad, logga in eller registrera dig för att kunna göra detta", "Hem", "/login")
    end
end

#Hämta tids-datan från formuläret där man skickar in tider
def get_form_time_info()
    return [params[:hours], params[:minutes], params[:seconds], params[:fractions].to_i].map(&:to_i)
end