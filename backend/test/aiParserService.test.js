import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  AiParserService,
  heuristicParseIndonesian,
  buildParserSystemPrompt,
} from '../src/services/aiParserService.js';

describe('9Router AI Parser Service Tests', () => {
  describe('1. Heuristic Local Parser (Indonesian Patterns)', () => {
    it('parses typical Indonesian expense with "rb" suffix', () => {
      const result = heuristicParseIndonesian('Makan siang ayam geprek 25rb');

      assert.equal(result.success, true);
      assert.equal(result.amount, 25000);
      assert.equal(result.type, 'expense');
      assert.equal(result.category, 'Makan & Minuman');
      assert.ok(result.reasoning.includes('makanan'));
    });

    it('parses transportation expense with fuel keyword', () => {
      const result = heuristicParseIndonesian('Beli bensin pertamax 50rb');

      assert.equal(result.success, true);
      assert.equal(result.amount, 50000);
      assert.equal(result.type, 'expense');
      assert.equal(result.category, 'Transportasi');
    });

    it('parses decimal income with "jt" (juta) suffix', () => {
      const result = heuristicParseIndonesian('Gajian freelance desain 2,5jt');

      assert.equal(result.success, true);
      assert.equal(result.amount, 2500000);
      assert.equal(result.type, 'income');
      assert.equal(result.category, 'Freelance');
    });

    it('parses with custom category matching', () => {
      const customCategories = ['Gym & Fitness', 'Skincare'];
      const result = heuristicParseIndonesian('Bayar member gym bulanan 150rb', customCategories);

      assert.equal(result.success, true);
      assert.equal(result.amount, 150000);
      assert.equal(result.category, 'Gym & Fitness');
    });

    it('gracefully rejects non-transaction casual greetings', () => {
      const result = heuristicParseIndonesian('Halo apa kabar bot?');

      assert.equal(result.success, false);
      assert.ok(result.error);
    });

    it('gracefully rejects text without identifiable numbers', () => {
      const result = heuristicParseIndonesian('Hari ini panas banget mau minum');

      assert.equal(result.success, false);
      assert.ok(result.error);
    });
  });

  describe('2. 9Router Prompt Builder', () => {
    it('includes user custom categories in system prompt', () => {
      const prompt = buildParserSystemPrompt(['Langganan AI', 'Koleksi Buku']);

      assert.ok(prompt.includes('Kategori yang tersedia saat ini'));
      assert.ok(prompt.includes('Langganan AI'));
      assert.ok(prompt.includes('Koleksi Buku'));
      assert.ok(prompt.includes('confidenceScore'));
    });
  });

  describe('3. 9Router API Interaction & Resilience', () => {
    it('successfully calls 9Router proxy and parses JSON response', async () => {
      let capturedRequest = null;

      const mockFetch = async (url, options) => {
        capturedRequest = { url, options };
        return {
          ok: true,
          status: 200,
          json: async () => ({
            choices: [
              {
                message: {
                  content: JSON.stringify({
                    success: true,
                    amount: 35000,
                    type: 'expense',
                    typeReasoning: 'Pengeluaran kopi sore',
                    category: 'Makan & Minuman',
                    confidence: 0.98,
                    reasoning: 'Kopi latte termasuk kategori Makan & Minuman',
                    note: 'Kopi latte gula aren',
                  }),
                },
              },
            ],
          }),
        };
      };

      const parser = new AiParserService({
        apiKey: 'test-9router-key',
        baseUrl: 'https://proxy.9router.test/v1',
        fetchFn: mockFetch,
      });

      const res = await parser.parseTransaction('Kopi latte gula aren 35rb');

      assert.equal(res.success, true);
      assert.equal(res.amount, 35000);
      assert.equal(res.category, 'Makan & Minuman');
      assert.equal(res.confidence, 0.98);

      // Verify request structure
      assert.equal(capturedRequest.url, 'https://proxy.9router.test/v1/chat/completions');
      assert.equal(capturedRequest.options.headers.Authorization, 'Bearer test-9router-key');
    });

    it('falls back to heuristic parser on 9Router 500 error', async () => {
      const mockFailingFetch = async () => ({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
      });

      const parser = new AiParserService({
        apiKey: 'test-9router-key',
        fetchFn: mockFailingFetch,
      });

      const res = await parser.parseTransaction('Beli martabak manis 30rb');

      // Even though 9Router failed with 500, local heuristic fallback saved the transaction!
      assert.equal(res.success, true);
      assert.equal(res.amount, 30000);
      assert.equal(res.category, 'Makan & Minuman');
    });

    it('falls back to heuristic parser on network timeout', async () => {
      const mockTimeoutFetch = async () => {
        throw new Error('Connection timed out');
      };

      const parser = new AiParserService({
        apiKey: 'test-9router-key',
        fetchFn: mockTimeoutFetch,
      });

      const res = await parser.parseTransaction('Gaji kantor 8jt');

      assert.equal(res.success, true);
      assert.equal(res.amount, 8000000);
      assert.equal(res.type, 'income');
      assert.equal(res.category, 'Gaji');
    });

    it('handles AI response indicating non-transaction text', async () => {
      const mockFetch = async () => ({
        ok: true,
        status: 200,
        json: async () => ({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  success: false,
                  error: 'Pesan hanya berupa sapaan santai.',
                }),
              },
            },
          ],
        }),
      });

      const parser = new AiParserService({
        apiKey: 'test-9router-key',
        fetchFn: mockFetch,
      });

      const res = await parser.parseTransaction('Selamat pagi');

      assert.equal(res.success, false);
      assert.equal(res.error, 'Pesan hanya berupa sapaan santai.');
    });
  });
});
