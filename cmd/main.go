package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"time"
)

// Структура для хранения данных запроса
type Request struct {
	ID     int
	Method string
	Path   string
}

// Структура для хранения данных ответа
type Response struct {
	ID     int
	Status int
	Body   string
}

func main() {
	// Создаем каналы для запросов и ответов
	requests := make(chan Request)
	responses := make(chan Response)

	// Запускаем горутину для обработки запросов
	go handleRequests(requests, responses)

	// Запускаем HTTP-сервер
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Генерируем уникальный ID для запроса
		id := rand.Intn(1000)

		// Отправляем запрос в канал
		requests <- Request{ID: id, Method: r.Method, Path: r.URL.Path}

		// Ожидаем ответ из канала
		response := <-responses

		// Отправляем ответ клиенту
		w.WriteHeader(response.Status)
		fmt.Fprint(w, response.Body)
	})

	// Запускаем сервер на порту 8080
	log.Println("Сервер запущен на http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

// Функция для обработки запросов
func handleRequests(requests <-chan Request, responses chan<- Response) {
	for req := range requests {
		// Имитируем обработку запроса
		time.Sleep(time.Millisecond * 100)

		// Формируем ответ
		resp := Response{
			ID:     req.ID,
			Status: http.StatusOK,
			Body:   fmt.Sprintf("Обработан запрос %d: %s %s", req.ID, req.Method, req.Path),
		}

		// Отправляем ответ в канал
		responses <- resp

		// Логируем информацию о запросе
		log.Printf("Обработан запрос: ID=%d, Method=%s, Path=%s\n", req.ID, req.Method, req.Path)
	}
}
