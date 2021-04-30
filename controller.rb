require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

include Model

# Visa startsida
#
get('/') do
    slim(:index)
end

# Sida som informerar användaren om nånting
# 
get('/inform') do
    message = session[:message]
    link_text = session[:link_text]
    link = session[:link]
    if message == nil || link_text == nil || link == nil
        #Om det i framtiden läggs till flera error-hanterare och man missar att
        #specifiera en beskrivning av felmeddelandet så visas detta som default
        message = "Det har uppstått ett fel, vänligen kontakta Ludvig Sandh."
        link_text = "Hem"
        link = "/"
    end
    slim(:"helper/inform", locals: {message: message, link_text: link_text, link: link})
end

# Omdirigerar användaren till en sida som visar information till användaren
#
# @param [String] mes meddelande som ska visas
# @param [String] link_t länktext som ska visas
# @param [String] link routen som användaren ska skickas till
def display_information(mes, link_t, link)
    session[:message] = mes
    session[:link_text] = link_t
    session[:link] = link
    redirect('/inform')
end

# Visar alla kategorier som finns
#
get('/categories') do
    #Hämta alla kategorier som finns
    categories = get_all_categories()
    
    #Visa dem för användaren
    slim(:"categories/index", locals: {categories: categories})
end

# Visar ett formulär som användaren kan fylla i för att skapa en ny kategori
# 
get('/categories/new') do
    #Detta får bara inloggade användare göra
    confirm_logged_in()

    #Visa formuläret för den som var inloggad
    slim(:"categories/new")
end

# Visar alla tider för en viss kategori
# 
# @param [Integer] :id id:t för kategorin vi tittar på
# @see Model#get_all_times_from_category
# @see Model#get_category
# @see Model#sort_times
# @see Model#get_username_with_id
# @see Model#get_rel
# @see Model#get_all_users_liking_category
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

# Visar ett formulär där man kan ändra ett kategorinamn
# 
# @param [Integer] :id id:t för kategorin vi tittar på
# @see get_user_id
# @see Model#get_category
# @see display_information
get('/categories/:id/edit') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]

    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if !user_is_owner(user_id, owner_id)
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorin", "/categories/#{category_id}")
    else
        slim(:"categories/edit", locals: {category: category})
    end
end

# Uppdaterar ett kategorinamn
# 
# @param [Integer] :id id:t för kategorin vi tittar på
# @see get_user_id
# @see Model#get_category
# @see display_information
# @see Model#name_accepted?
# @see Model#exists_category_name?
# @see Model#update_category_name
post('/categories/:id/update') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if !user_is_owner(user_id, owner_id)
        display_information("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Tillbaka till kategorier", "/categories/#{category_id}")
    end
    
    #Användaren är authorized. Hämta datan, dvs det nya namnet på kategorin, från formuläret
    new_cat_name = params[:new_name]

    #Kontrollera att det nya kategorinamnet är tillåtet
    if name_accepted?(new_cat_name)

        #Kontrollera att det inte redan finns en kategori med detta namnet
        if !exists_category_name?(new_cat_name)

            #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
            update_category_name(new_cat_name, category_id)

            #Skicka användaren till den nyligen skapade kategorin
            redirect("/categories/#{category_id}")
        else
            display_information("Det finns redan en kategori med detta namnet", "Prova igen", "/categories/new")
        end
    else
        display_information("Ditt kategorinamn får inte vara tomt eller bestå av endast blanksteg", "Prova igen", "/categories/new")
    end
end

# Raderar en kategori
# 
# @param [Integer] :id id:t för kategorin vi tittar på
# @see get_user_id
# @see Model#get_category
# @see display_information
# @see Model#delete_category
post('/categories/:id/delete') do
    #Hämta kategori-id som vi hanterar (från parametrar)
    category_id = params[:id]
    
    #Hämta användar-id: (bara inloggade användare får ändra på en kategori)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    category = get_category(category_id)
    owner_id = category["user_id"]

    #Det är naturligtvis bara den som skapat (äger) denna kategorin som får radera den
    if !user_is_owner(user_id, owner_id)
        display_information("Du är inte skaparen av denna kategorin. Du kan inte radera en kategori som någon annan äger", "Tillbaka till kategorier", "/categories/#{category_id}")
    else
        #Vi raderar kategorin, samt alla tider som hör till denna kategorin
        delete_category(category_id)
    end
    
    #Skicka tillbaka användaren till kategorilistan
    redirect("/categories")
end

# Skapar en ny kategori i databasen
# 
# @see get_user_id
# @see name_accepted?
# @see Model#exists_category_name?
# @see Model#insert_category
# @see Model#insert_category
# @see display_information
post('/categories') do
    #Detta får bara inloggade användare göra
    user_id = get_user_id()

    #Hämta data från formuläret
    cat_name = params[:name]

    #Kontrollera att det nya kategorinamnet är tillåtet
    if name_accepted?(cat_name)

        #Kontrollera att det inte redan finns en kategori med detta namnet
        if !exists_category_name?(cat_name)

            #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
            insert_category(cat_name, user_id)

            #Skicka tillbaka användaren till kategorilistan
            redirect('/categories')
        else
            display_information("Det finns redan en kategori med detta namnet", "Prova igen", "/categories/new")
        end
    else
        display_information("Ditt kategorinamn får inte vara tomt eller bestå av endast blanksteg", "Prova igen", "/categories/new")
    end
end

# Visar alla tider som finns i en kategori
# 
# @param [Integer] :category_id id:t för kategorin som tiden finns i
# @see confirm_logged_in
# @see Model#get_category
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

# Visar detaljer om en specifik tid
# 
# @param [Integer] :category_id id:t för kategorin som tiden finns i
# @param [Integer] :time_id id:t för tiden som vi kollar på
# @see Model#get_category
# @see Model#get_time
# @see Model#get_username_with_id
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

# Skapar en ny tid
# 
# @param [Integer] :category_id id:t för kategorin som tiden ska läggas till i
# @see get_user_id
# @see Model#get_form_time_info
# @see Model#check_time_input_accepted
# @see Model#time_to_string
# @see Model#insert_time
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

# Raderar en tid
# 
# @param [Integer] :category_id id:t för kategorin som tiden finns i
# @param [Integer] :time_id id:t för tiden som ska raderas
# @see get_user_id
# @see Model#get_time_user_id
# @see display_information
# @see Model#delete_time
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
    if !user_is_owner(user_id, owner_id)
        display_information("Du är inte skaparen av denna tiden. Du kan inte radera en tid som tillhör någon annan", "Tillbaka till tiden", "/times/#{category_id}/#{time_id}")
    else
        #Vi raderar tiden
        delete_time(time_id)
    end
    
    #Skicka tillbaka användaren till tidslistan
    redirect("/categories/#{category_id}")
end

# Visar sidan där användaren kan logga in med hjälp av ett formulär
# 
get('/login') do
    slim(:"auth/login")
end

# Loggar in användaren
#
# @param [String] :username_input användarens inskrivna användarnamn
# @param [String] :password_input användarens inskrivna lösenord
# @see Model#get_user_with_username
# @see display_information
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

        #Kontrollera att lösenordet var rätt
        if correct_password?(password_digest, password_input)

            #Hämta användar-id hos usern
            user_id = user["id"]

            #Spara användar-id i sessions så att användaren kan fortsätta vara inloggad medan hen besöker hemsidan
            session[:user_id] = user_id

            #Spara användarnamnet i sessions också så att vi lätt kan komma åt det
            session[:username] = username_input

            #Informera användaren att hen är inloggad
            display_information("Välkommen tillbaka #{username_input}! Du är nu inloggad.", "Ta mig till startsidan", "/")
        else
            #Lösenordet stämde inte
            display_information("Du har skrivit in fel användarnamn eller lösenord", "Prova igen", "/login")
        end
    end
    
    #metoden display_information redirectar användaren så en redirect här behövs inte
end

# Loggar ut användaren
#
get('/logout') do
    session[:user_id] = nil
    session[:username] = nil
    slim(:"auth/logout")
end

# Visar sidan där användare kan registrera sig med hjälp av ett formulär
#
get('/users/new') do
    slim(:"users/new")
end

# Lägger till en ny användare i databasen
#
# @param [String] :username_input användarens inskrivna användarnamn
# @param [String] :password_input användarens inskrivna lösenord
# @param [String] :password_confirm_input användarens inskrivna bekräftade lösenord
# @see Model#exists_username?
# @see Model#name_accepted?
# @see display_information
# @see Model#insert_user
# @see Model#get_user_id_with_username
post('/users') do
    #Hämta användarnamnet som användaren skrev in (input i formuläret)
    username_input = params[:username_input]

    #Hämta lösenordet som användaren skrev in
    password_input = params[:password_input]

    #Hämta det bekräftade lösenordet som användaren skrev in
    password_confirm_input = params[:password_confirm_input]

    #Om det inte fanns någon användare med detta användarnamnet redan
    if !exists_username?(username_input)
        
        #Se till att det bekräftade lösenordet är samma
        if same_password(password_input, password_confirm_input)

            #Kontrollera att användarnamnet är accepterat
            if !name_accepted?(username_input)
                display_information("Ditt användarnamn får inte vara tomt eller bestå av endast blanksteg", "Prova igen", "/users/new")
            end

            #Kontrollera att lösenordet är accepterat
            if !password_accepted?(password_input)
                display_information("Ditt lösenord måste bestå av minst 8 distinkta tecken", "Prova igen", "/users/new")
            end

            #Kryptera lösenordet
            password_digest = encrypt_password(password_input)

            insert_user(username_input, password_digest)
            
            #Hitta användarens id från databasen och spara det i session
            user_id = get_user_id_with_username(username_input)["id"]
            session[:user_id] = user_id
            session[:username] = username_input

            display_information("Hej #{username_input}! Du har nu registrerat dig!", "Ta mig till startsidan", "/")
        else
            display_information("Lösenordet stämde inte överens med det bekräftade lösenordet", "Prova igen", "/users/new")
        end
    else
        display_information("Det finns redan en användare med användarnamnet #{username_input}", "Prova igen", "/users/new")
    end

    #metoden display_information redirectar användaren så en redirect här behövs inte
end

# Visar profilen för en användare
#
# @param [String] :id användarens id
# @see Model#get_user
# @see Model#get_all_categories_by_user_id?
# @see Model#get_all_times_by_user_id
# @see Model#get_category_name
# @see Model#get_all_categories_liked_by_user
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

# Visar formuläret där användaren kan ändra sitt lösenord
#
# @param [id] :id användarens user-id
# @see Model#get_user
get('/users/:id/edit') do
    #Hämta användar-id:t som vi vill kolla profilen för
    profile_user_id = params[:id]

    #Hämta information om profilen
    user = get_user(profile_user_id)

    slim(:"users/edit", locals: {user: user})
end

# Uppdatera användarens lösenord
#
# @param [Integer] :id användarens user-id
# @see display_information
# @see Model#get_user
# @see Model#update_password
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

        #Kontrollera att det nya lösenordet är accepterat
        if !password_accepted?(new_password_input)
            display_information("Ditt lösenord måste bestå av minst 8 distinkta tecken", "Prova igen", "/users/#{profile_user_id}/show")
        end

        #Hämta det krypterade lösenordet från användaren
        user = get_user(user_id)

        #Det lagrade krypterade lösenordet för användaren
        password_digest = user["pw_digest"]

        #Kontrollera att lösenordet var rätt
        if correct_password?(password_digest, current_password_input)
            #Kontrollera att lösenordet stämmer överens med det bekräftade lösenordet
            if same_password(new_password_input, confirm_new_password_input)
                #Kryptera det nya lösenordet
                password_digest = encrypt_password(new_password_input)
                
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

# Skapa en "Like", dvs en relation mellan entiteten Users och Cateories
#
# @param [Integer] :user_id användarens user-id
# @param [Integer] :category_id kategorins id
# @see display_information
# @see Model#get_rel
# @see Model#delete_rel
# @see Model#insert_rel
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

# Hämta användar-id:t hos den inloggade användaren (från sessions)
# 
def get_user_id()
    return session[:user_id]
end

# Ser till att användaren är inloggad, annars visas meddelande
#
# @see display_information
def confirm_logged_in()
    if session[:user_id] == nil
        display_information("Du är inte inloggad, logga in eller registrera dig för att kunna göra detta", "Hem", "/login")
    end
end

# Hämtar tids-datan från formuläret där man skickar in tider
# 
def get_form_time_info()
    return [params[:hours], params[:minutes], params[:seconds], params[:fractions].to_i].map(&:to_i)
end